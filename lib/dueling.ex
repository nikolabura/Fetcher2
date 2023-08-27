defmodule Fetcher2.Dueling.State.AwaitingAcceptance do
  alias Nostrum.Struct.Interaction
  use TypedStruct

  typedstruct do
    field(:timer, any())
    field(:interaction, Interaction)
    field(:challenger, integer())
    field(:challenged, integer())
  end
end

defmodule Fetcher2.Dueling.State.MakingChoices do
  alias Nostrum.Struct.Interaction
  use TypedStruct

  typedstruct do
    field(:challenger_id, integer())
    field(:challenged_id, integer())
    field(:challenger_orig_interaction, Interaction)
    field(:challenger_followup_message, Message)
    field(:challenged_interaction, Interaction)
    field(:challenger_shoot_choice, :left | :middle | :right)
    field(:challenged_shoot_choice, :left | :middle | :right)
    field(:challenger_dodge_choice, :left | :middle | :right)
    field(:challenged_dodge_choice, :left | :middle | :right)
  end
end

defmodule Fetcher2.Dueling.State.CountingDown do
  alias Nostrum.Struct.Interaction
  use TypedStruct

  typedstruct do
    field(:challenger_id, integer())
    field(:challenged_id, integer())
    field(:challenger_shoot_choice, :left | :middle | :right)
    field(:challenged_shoot_choice, :left | :middle | :right)
    field(:challenger_dodge_choice, :left | :middle | :right)
    field(:challenged_dodge_choice, :left | :middle | :right)
    field(:channel_id, integer())
    field(:draw_button_message, Message)
    field(:next_phase, :three | :two | :one | :draw | :stop)
    field(:draw_command_time_ms, integer())
    field(:challenger_shoot_time_ms, integer())
    field(:challenged_shoot_time_ms, integer())
  end
end

defmodule Fetcher2.Dueling do
  use GenServer
  import Bitwise

  require Logger
  alias Fetcher2.Dueling.State.CountingDown
  alias Fetcher2.Dueling.State.MakingChoices
  alias Fetcher2.Dueling.State.AwaitingAcceptance
  alias Nostrum.Api
  alias Nostrum.Struct.Interaction

  def start_link(default) do
    GenServer.start_link(__MODULE__, default, name: Fetcher2.Dueling)
  end

  @impl true
  def init(_) do
    {:ok, nil}
  end

  # HANDLE INITIAL ENTRY
  @impl true
  def handle_call({:start_duel, interaction}, _from, state) do
    %Interaction{data: %{options: options}} = interaction

    {response, new_state} =
      if state == nil do
        # If the state is currently empty (no duel) let's try and start a new one
        challenger_id = interaction.member.user_id
        [%{value: challenged_id} | _] = options

        Logger.info("#{challenger_id} has challenged #{challenged_id} to a duel!")

        cond do
          challenger_id == challenged_id ->
            # Can't duel yourself. :(
            {%{
               type: 4,
               data: %{
                 content: "I don't know about that one, man."
               }
             }, nil}

          challenged_id == Nostrum.Cache.Me.get().id ->
            # Can't duel the bot!
            {%{
               type: 4,
               data: %{
                 content: "You dare challenge the bot itself?"
               }
             }, nil}

          true ->
            # Conditions are good to start a new duel. Ask the challenged if they accept. Will ↓↓ time out after this many seconds
            cancel_acceptance_timer = Process.send_after(self(), :acceptance_timed_out, 1000 * 30)

            {
              challenge_message(challenger_id, challenged_id),
              %AwaitingAcceptance{
                timer: cancel_acceptance_timer,
                interaction: interaction,
                challenger: challenger_id,
                challenged: challenged_id
              }
            }
        end
      else
        {%{
           type: 4,
           data: %{
             content: "A duel is already in progress. Cool the bloodlust a bit."
           }
         }, state}
      end

    Api.create_interaction_response!(interaction, response)

    {:reply, nil, new_state}
  end

  # HANDLE ACCEPTED DUEL
  @impl true
  def handle_call(
        {:button_press, "duel_accept", button_interaction},
        _,
        state = %AwaitingAcceptance{
          timer: timer_handle,
          interaction: orig_interaction,
          challenger: challenger_id,
          challenged: challenged_id
        }
      ) do
    if challenged_id == button_interaction.member.user_id do
      Logger.info("Duel was accepted!")

      # Kill the timer before it goes off
      Process.cancel_timer(timer_handle)

      Api.edit_interaction_response!(orig_interaction, %{
        content:
          "<@#{challenged_id}> has accepted <@#{challenger_id}>'s challenge to duel. The fight is on!",
        components: []
      })

      # Create the challenged's UI (just a response to their interaction)
      Api.create_interaction_response!(button_interaction, %{
        type: 4,
        data: render_choice_buttons(:middle, :middle)
      })

      # Create the challenger's UI (a separate message)
      challenger_message =
        Api.create_followup_message!(
          orig_interaction.token,
          render_choice_buttons(:middle, :middle)
        )

      # After five seconds, update the messages. After ten, lock them in
      Process.send_after(self(), :five_seconds_to_make_choices, 1000 * 2)
      Process.send_after(self(), :choices_locked_in, 1000 * 4)

      # Proceed to the making choices state
      {:reply, nil,
       %MakingChoices{
         challenged_id: challenged_id,
         challenger_id: challenger_id,
         challenger_orig_interaction: orig_interaction,
         challenger_followup_message: challenger_message,
         challenged_interaction: button_interaction,
         challenged_dodge_choice: :middle,
         challenged_shoot_choice: :middle,
         challenger_dodge_choice: :middle,
         challenger_shoot_choice: :middle
       }}
    else
      # Unrelated user; disregard
      Api.create_interaction_response!(button_interaction, %{type: 6})
      {:reply, nil, state}
    end
  end

  # HANDLE DECLINED DUEL
  @impl true
  def handle_call(
        {:button_press, "duel_decline", button_interaction},
        _,
        state = %AwaitingAcceptance{
          timer: timer_handle,
          interaction: interaction,
          challenger: challenger_id,
          challenged: challenged_id
        }
      ) do
    if challenged_id == button_interaction.member.user_id do
      Logger.info("Duel was declined.")

      # Kill the timer before it goes off
      Process.cancel_timer(timer_handle)

      Api.edit_interaction_response!(interaction, %{
        content:
          "<@#{challenged_id}> declined <@#{challenger_id}>'s duel challenge. Such dishonor! <a:disapproval:1080692559376044112>",
        components: []
      })

      # Clear the state
      {:reply, nil, nil}
    else
      # Unrelated user; disregard
      Api.create_interaction_response!(button_interaction, %{type: 6})
      {:reply, nil, state}
    end
  end

  # HANDLE PRE-DUEL CHOICE BUTTONS
  @impl true
  def handle_call(
        {:choice_button, chosen_button, button_interaction},
        _,
        %MakingChoices{} = state
      ) do
    Logger.info("Pre-duel choice button pressed.")

    [_, choice, direction] = String.split(chosen_button, "_")

    # otherwise, challenger
    challenged_choosing = state.challenged_id == button_interaction.member.user_id

    key_to_update =
      case {choice, challenged_choosing} do
        {"shoot", true} -> :challenged_shoot_choice
        {"dodge", true} -> :challenged_dodge_choice
        {"shoot", false} -> :challenger_shoot_choice
        {"dodge", false} -> :challenger_dodge_choice
      end

    state_out =
      Map.put(
        state,
        key_to_update,
        case direction do
          "left" -> :left
          "middle" -> :middle
          "right" -> :right
        end
      )

    if challenged_choosing do
      Api.edit_interaction_response!(state.challenged_interaction, %{
        components:
          render_choice_buttons(
            state_out.challenged_shoot_choice,
            state_out.challenged_dodge_choice
          ).components
      })
    else
      {:ok, _} =
        Api.request(
          :patch,
          Nostrum.Constants.webhook_message(
            Nostrum.Cache.Me.get().id,
            state.challenger_orig_interaction.token,
            state.challenger_followup_message.id
          ),
          %{
            components:
              render_choice_buttons(
                state_out.challenger_shoot_choice,
                state_out.challenger_dodge_choice
              ).components
          },
          wait: false
        )
    end

    Api.create_interaction_response!(button_interaction, %{type: 6})
    {:reply, nil, state_out}
  end

  # HANDLE DRAW BUTTON
  @impl true
  def handle_call(
        {:button_press, "duel_draw", button_interaction},
        _,
        state
      ) do
    Logger.info("User pushed DRAW!")
    alias Fetcher2.Dueling.State.CountingDown
    got_time = System.monotonic_time(:millisecond)

    # In the interest of latency/avoiding hogging the Dueling GenServer, all API calls in this function go async
    Task.start(fn -> Api.create_interaction_response!(button_interaction, %{type: 6}) end)

    gen_text = fn id, shoot, dodge ->
      aim =
        case shoot do
          :left -> "to the left"
          :middle -> "straight ahead"
          :right -> "to the right"
        end

      case dodge do
        :left ->
          "<@#{id}> draws their weapon as they dodge to the left. Aiming #{aim}, they fire! **BANG!**"

        :middle ->
          "<@#{id}> draws their weapon, standing their ground as they aim #{aim}. They fire! **BANG!**"

        :right ->
          "<@#{id}> draws their weapon as they dodge to the right. Aiming #{aim}, they fire! **BANG!**"
      end
    end

    state_out =
      case state do
        %CountingDown{
          next_phase: :stop,
          challenged_id: challenged_id,
          challenger_id: challenger_id
        } ->
          case button_interaction.member.user_id do
            ^challenger_id ->
              Logger.info("Challenger has DRAWN their weapon!")

              {out_state, content} =
                if state.challenger_shoot_time_ms == nil do
                  {%{state | challenger_shoot_time_ms: got_time},
                   gen_text.(
                     challenger_id,
                     state.challenger_shoot_choice,
                     state.challenger_dodge_choice
                   )}
                else
                  {state, "<@#{challenger_id}> fires again!"}
                end

              Task.start(fn -> Api.create_message!(state.channel_id, content: content) end)

              out_state

            ^challenged_id ->
              Logger.info("Challenged has DRAWN their weapon!")

              {out_state, content} =
                if state.challenged_shoot_time_ms == nil do
                  {%{state | challenged_shoot_time_ms: got_time},
                   gen_text.(
                     challenged_id,
                     state.challenged_shoot_choice,
                     state.challenged_dodge_choice
                   )}
                else
                  {state, "<@#{challenged_id}> fires again!"}
                end

              Task.start(fn -> Api.create_message!(state.channel_id, content: content) end)

              out_state

            _ ->
              # it's some random user
              state
          end

        _ ->
          # we're not in the right phase
          state
      end

    {:reply, nil, state_out}
  end

  defp render_choice_buttons(shoot_choice, dodge_choice) do
    %{
      content:
        "Here we go! Make your choices for the duel.\nYou have **ten seconds** before your choices are locked in.\nYour opponent cannot see your choices.",
      flags: 1 <<< 6,
      components: [
        %{
          type: 1,
          components: [
            %{
              type: 2,
              label: "Shoot left",
              style: if(shoot_choice == :left, do: 1, else: 2),
              custom_id: "duel_shoot_left",
              emoji: %{id: 596_181_136_535_978_004, name: "worryshootleft"}
            },
            %{
              type: 2,
              label: "Shoot straight ahead",
              style: if(shoot_choice == :middle, do: 1, else: 2),
              custom_id: "duel_shoot_middle",
              emoji: %{id: 708_907_849_128_083_516, name: "worryshootmiddle"}
            },
            %{
              type: 2,
              label: "Shoot right",
              style: if(shoot_choice == :right, do: 1, else: 2),
              custom_id: "duel_shoot_right",
              emoji: %{id: 596_181_136_523_395_081, name: "worryshootright"}
            }
          ]
        },
        %{
          type: 1,
          components: [
            %{
              type: 2,
              label: "Dodge left",
              style: if(dodge_choice == :left, do: 1, else: 2),
              custom_id: "duel_dodge_left",
              emoji: %{id: 908_243_804_350_472_232, name: "worrydodgeleft"}
            },
            %{
              type: 2,
              label: "Stand your ground",
              style: if(dodge_choice == :middle, do: 1, else: 2),
              custom_id: "duel_dodge_middle",
              emoji: %{id: 1_089_013_563_915_513_886, name: "worrystare"}
            },
            %{
              type: 2,
              label: "Dodge right",
              style: if(dodge_choice == :right, do: 1, else: 2),
              custom_id: "duel_dodge_right",
              emoji: %{id: 1_145_182_937_374_011_402, name: "worrydodgeright"}
            }
          ]
        }
      ]
    }
  end

  defp challenge_message(challenger_id, challenged_id) do
    %{
      type: 4,
      data: %{
        content:
          "<@#{challenger_id}> has challenged <@#{challenged_id}> to a duel! :crossed_swords:\n\n**<@#{challenged_id}>, make your choice...**",
        components: [
          %{
            type: 1,
            components: [
              %{
                type: 2,
                label: "Accept Duel",
                style: 3,
                custom_id: "duel_accept",
                emoji: %{id: 469_522_524_049_244_160, name: "worrysword"}
              },
              %{
                type: 2,
                label: "Decline Duel",
                style: 4,
                custom_id: "duel_decline",
                emoji: %{id: 958_569_251_319_455_774, name: "worryleave"}
              }
            ]
          }
        ]
      }
    }
  end

  # HANDLE ACCEPTANCE TIME OUT
  @impl true
  def handle_info(
        :acceptance_timed_out,
        %AwaitingAcceptance{
          interaction: interaction,
          challenger: challenger_id,
          challenged: challenged_id
        }
      ) do
    Logger.info("Duel acceptance timed out. What cowardice.")

    Api.edit_interaction_response!(interaction, %{
      content:
        "<@#{challenged_id}> failed to respond to <@#{challenger_id}>'s duel challenge in time. What cowardice! <a:disapproval:1080692559376044112>",
      components: []
    })

    # Clear the state
    {:noreply, nil}
  end

  # HANDLE FIVE SECONDS LEFT TO CHOOSE
  @impl true
  def handle_info(
        :five_seconds_to_make_choices,
        %MakingChoices{
          challenged_interaction: challenged_interaction,
          challenger_followup_message: challenger_message,
          challenger_orig_interaction: challenger_orig_interaction
        } = state
      ) do
    Logger.info("Five seconds left to make choices.")

    new_str =
      "Here we go! Make your choices for the duel.\nYou have **five seconds** before your choices are locked in.\nYour opponent cannot see your choices."

    Api.edit_interaction_response!(challenged_interaction, %{content: new_str})

    {:ok, _} =
      Api.request(
        :patch,
        Nostrum.Constants.webhook_message(
          Nostrum.Cache.Me.get().id,
          challenger_orig_interaction.token,
          challenger_message.id
        ),
        %{content: new_str},
        wait: false
      )

    # Maintain state
    {:noreply, state}
  end

  # HANDLE CHOICES LOCKED IN
  @impl true
  def handle_info(
        :choices_locked_in,
        %MakingChoices{
          challenged_interaction: challenged_interaction,
          challenger_followup_message: challenger_message,
          challenger_orig_interaction: challenger_orig_interaction
        } = state
      ) do
    Logger.info("Choices are now locked in.")

    gen_str = fn shoot, dodge ->
      "Your choices are now locked in. You will " <>
        case shoot do
          :left -> "shoot to your left"
          :middle -> "shoot straight forwards"
          :right -> "shoot to your right"
        end <>
        " and " <>
        case dodge do
          :left -> "dodge to your left."
          :middle -> "stand your ground."
          :right -> "dodge to your right."
        end
    end

    # Remove the challenged's UI
    Api.edit_interaction_response!(challenged_interaction, %{
      content: gen_str.(state.challenged_shoot_choice, state.challenged_dodge_choice),
      components: []
    })

    # Remove the challenger's UI
    {:ok, _} =
      Api.request(
        :patch,
        Nostrum.Constants.webhook_message(
          Nostrum.Cache.Me.get().id,
          challenger_orig_interaction.token,
          challenger_message.id
        ),
        %{
          content: gen_str.(state.challenger_shoot_choice, state.challenger_dodge_choice),
          components: []
        },
        wait: false
      )

    Api.create_message!(challenger_orig_interaction.channel_id,
      content:
        "https://cdn.discordapp.com/attachments/552980096315686955/1145201181338116177/tension.gif"
    )

    draw_button_message =
      Api.create_message!(challenger_orig_interaction.channel_id,
        content:
          "I will count down from three. When I say **draw**, " <>
            "you may press the button below to draw your weapon and fire. " <>
            "You also have the choice to spare your opponent by **not** drawing your weapon. " <>
            "But be careful - being bound by honor, you can't draw until I've called it.",
        components: [
          %{
            type: 1,
            components: [
              %{
                type: 2,
                label: "Draw",
                style: 4,
                custom_id: "duel_draw"
              }
            ]
          }
        ]
      )

    # Wait six seconds before the countdown
    Process.send_after(self(), :countdown_cycle, 6000)

    # Note from testing: Api.create_message! takes between 0.13s and 0.48s to return, with the average being reliably 0.2s or so

    new_state = struct(CountingDown, Map.from_struct(state))

    new_state = %{
      new_state
      | channel_id: challenger_orig_interaction.channel_id,
        next_phase: :three,
        draw_button_message: draw_button_message
    }

    # Next state
    {:noreply, new_state}
  end

  # HANDLE COUNTDOWN CYCLE
  @impl true
  def handle_info(
        :countdown_cycle,
        %CountingDown{channel_id: channel_id, next_phase: phase} = state
      ) do
    Logger.info("Countdown cycle #{phase}.")

    next_state =
      case phase do
        :three ->
          Api.create_message!(channel_id, content: "Three... <:frogenerv:1003791015284576356>")
          Process.send_after(self(), :countdown_cycle, 1300)
          %{state | next_phase: :two}

        :two ->
          Api.create_message!(channel_id, content: "Two... <:frogenerv:891833584132956181>")
          Process.send_after(self(), :countdown_cycle, 1300)
          %{state | next_phase: :one}

        :one ->
          Api.create_message!(channel_id, content: "One... <a:frogenerv:908239088514129920>")
          Process.send_after(self(), :countdown_cycle, 1300)
          %{state | next_phase: :draw}

        :draw ->
          Api.create_message!(channel_id, content: "## Draw!!")
          Process.send_after(self(), :countdown_cycle, 5000)
          %{state | next_phase: :stop, draw_command_time_ms: System.monotonic_time(:millisecond)}

        :stop ->
          Api.create_message!(channel_id, content: "## Stop!")

          Api.edit_message!(state.draw_button_message,
            components: [
              %{
                type: 1,
                components: [
                  %{
                    type: 2,
                    label: "Draw",
                    style: 4,
                    custom_id: "duel_draw",
                    disabled: "true"
                  }
                ]
              }
            ]
          )

          Process.sleep(1500)
          Api.create_message!(channel_id, content: "The dust slowly settles...")
          duel_finished(state)
          # The duel has concluded.
          nil
      end

    {:noreply, next_state}
  end

  defp duel_finished(%CountingDown{
    channel_id: channel_id
  } = state) do
  end
end
