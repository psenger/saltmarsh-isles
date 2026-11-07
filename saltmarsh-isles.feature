# Saltmarsh Isles: behaviour specification
# Matches the native app (SaltmarshCore) and saltmarsh-isles-spec.md.
# One Feature, grouped into Rules (Gherkin 6+). Player seats: Crimson, Cobalt, Amber, Ivory.
# "taps" means a click on a Mac or a tap on iPhone and iPad.
# Scenarios tagged @ui need a running app and live in AppUITests; every other scenario runs under `swift test`.

Feature: Saltmarsh Isles pass-and-play game
  As a group of 2 to 4 players sharing one device, or one player against AI seats
  We want to roll, gather resources, build, trade and play development cards
  So that the first player to 10 points wins

  Background:
    Given a new 3-player game with human seats

  # ─────────────────────────────────────────────────────────────
  Rule: Starting a new game

    Scenario: A new game starts with the first-player roll
      Then a 3-player game has started
      And the players are Crimson, Cobalt and Amber
      And the header shows "Crimson · first roll"
      And the status reads "Who sails first? Roll for it!"
      And the log contains "New game with 3 players. Everyone rolls for first player."

    Scenario Outline: Starting a game with a chosen player count
      When I start a <count>-player game
      Then the players are <players>
      And every player has 0 resource cards and 0 development cards
      And the development deck holds 25 cards

      Examples:
        | count | players                         |
        | 2     | Crimson, Cobalt                 |
        | 3     | Crimson, Cobalt, Amber          |
        | 4     | Crimson, Cobalt, Amber, Ivory   |

    Scenario: Starting a new game closes the win screen
      Given the victory screen is showing
      When I tap "New game" on the victory screen
      Then the victory screen is hidden
      And a new board is generated

  # ─────────────────────────────────────────────────────────────
  Rule: Choosing who goes first

    Scenario: Every seat rolls once, in seat order
      When Crimson rolls 9 for first player
      Then the log reads "Crimson rolled 9 (6+3) for first player."
      And the header shows "Cobalt · first roll"

    Scenario: The highest roll goes first
      When the first-player rolls are Crimson 3, Cobalt 12 and Amber 7
      Then the log reads "Cobalt goes first. Place your first settlement."
      And the header shows "Cobalt · setup"
      And the order strip shows Cobalt, Amber, Crimson, Crimson, Amber, Cobalt

    Scenario: A tie re-rolls among the tied seats only
      When the first-player rolls are Crimson 12, Cobalt 2 and Amber 12
      Then the log reads "Tie between Crimson and Amber. Roll again."
      And the header shows "Crimson · first roll"
      When Crimson rolls 4 for first player
      Then the header shows "Amber · first roll"
      When Amber rolls 10 for first player
      Then the log reads "Amber goes first. Place your first settlement."

    Scenario: Setup ends with the first player rolling
      Given Amber won the first roll
      When every setup placement is made
      Then the log reads "Setup done. Amber rolls first."
      And the header shows "Amber"

  # ─────────────────────────────────────────────────────────────
  Rule: The board is generated fairly

    Scenario: Board structure
      Then the board has 19 tiles, 54 corners, 72 edges and 30 coastal edges
      And the centre tile is the desert labelled "DUNES" with no number
      And the robber starts on the desert

    Scenario: Resource and number mix
      Then the 18 land tiles are 4 timber, 3 clay, 4 wool, 4 grain and 3 ore
      And the number discs are 2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12
      And each number disc shows dots equal to its pips
      And the number discs 6 and 8 are marked hot

    Scenario Outline: Balancing rules hold on every generated board
      When 200 boards are generated
      Then on every board <rule>

      Examples:
        | rule                                                                  |
        | no two tiles of the same resource are neighbours                      |
        | no 6 or 8 neighbours another 6 or 8                                    |
        | no number neighbours the same number                                  |
        | no corner touches more than 11 pips                                   |
        | each resource's pip total is within 3 of its fair share of 58 / 18    |

    Scenario: Harbour layout
      Then there are 9 harbours on coastal edges
      And 4 harbours trade at 3:1 and there is one 2:1 harbour for each resource
      And no two 3:1 harbours are neighbours around the coast
      And each harbour is joined by jetties to the 2 corners of its edge

  # ─────────────────────────────────────────────────────────────
  Rule: Setup uses snake order

    Scenario Outline: Placement order
      Given a new <count>-player game
      And Crimson won the first roll
      Then players place in the order <order>
      And after the last placement the log reads "Setup done. Crimson rolls first."

      Examples:
        | count | order                                                         |
        | 2     | Crimson, Cobalt, Cobalt, Crimson                              |
        | 3     | Crimson, Cobalt, Amber, Amber, Cobalt, Crimson                |
        | 4     | Crimson, Cobalt, Amber, Ivory, Ivory, Amber, Cobalt, Crimson  |

    Scenario: Placing a setup settlement
      Given it is Crimson's setup step
      Then every corner that obeys the distance rule glows
      When Crimson taps a glowing corner
      Then a Crimson settlement is placed there
      And the log reads "Crimson founded a settlement at V0."
      And the status reads "Now a road! Tap a dashed edge next to your settlement."
      And only edges touching that settlement are dashed

    Scenario: Placing a setup road passes the turn on
      Given Crimson has just placed a setup settlement
      When Crimson taps a dashed edge
      Then a Crimson road is placed there
      And the log reads "Crimson laid a road E0-1."
      And it becomes the next player's setup step

    Scenario: Only the second setup settlement pays starting cards
      Given Crimson's first setup settlement touches timber, clay and wool
      Then Crimson holds 0 cards after the first placement
      When Crimson's second setup settlement touches timber, clay and wool
      Then Crimson receives 1 timber, 1 clay and 1 wool

    Scenario: The desert pays nothing at setup
      When a player's second setup settlement touches the desert and 2 grain tiles
      Then that player receives 2 grain only

    Scenario: Normal actions are locked during setup
      Given the game is in setup
      Then "Roll dice", the build buttons, "Buy a card", trading and "End turn" are disabled

  # ─────────────────────────────────────────────────────────────
  Rule: Rolling and production

    Background:
      Given setup is complete
      And it is Crimson's turn and Crimson has not rolled

    Scenario: Start of turn
      Then the status reads "Your move, captain. Roll the dice!"
      And both dice show "–"
      And of the turn actions, only "Roll dice" and playable Knights are enabled

    Scenario: A roll that produces
      Given Cobalt has a settlement and Amber has a city on a tile numbered 8
      When Crimson rolls 8
      Then Cobalt receives 1 card of that tile's resource
      And Amber receives 2 cards of that tile's resource
      And the number discs showing 8 are marked hit
      And the log reads "Crimson rolled 8 (6+2). Cobalt +1 ore, Amber +2 ore"
      And the status reads "The isles are yours! Build, trade, or end your turn."

    Scenario: A roll that produces nothing
      When Crimson rolls a number no building touches
      Then the log ends with "Nobody harvested."

    Scenario: The robber blocks production
      Given the robber is on Cobalt's tile numbered 6
      When Crimson rolls 6
      Then Cobalt receives nothing from that tile

    Scenario: Roll is single use
      When Crimson rolls a number other than 7
      Then "Roll dice" is disabled until the next turn

  # ─────────────────────────────────────────────────────────────
  Rule: Rolling a 7 makes players over 7 cards discard half, chosen by them

    Background:
      Given setup is complete and it is Crimson's turn
      And Crimson holds 4 cards, Cobalt holds 9 cards and Amber holds 10 cards

    Scenario: Discard queue forms in seat order
      When Crimson rolls 7
      Then the log reads "Crimson rolled 7 (6+1)."
      And no tile produces
      And Cobalt must discard 4 and then Amber must discard 5
      And Crimson does not discard

    Scenario: The panel belongs to the discarding player
      When Crimson rolls 7
      Then the header shows "Cobalt · discarding" with Cobalt's colour
      And the status reads "Crimson rolled a 7! Cobalt has more than 7 cards and must give up half."
      And the hold is labelled "Cobalt's hold" and shows Cobalt's cards
      And the discard box is outlined in Cobalt's colour
      And the discard box reads "Oh NO! Cobalt, the robber needs 4 cards from your deck" with a counter "0 / 4"
      And the discard box lists only resources Cobalt holds, each as "0 of N"
      And the discard box shows "Next: Amber"

    Scenario: Everything else is locked during discards
      When Crimson rolls 7
      Then "Roll dice", the build buttons, "Buy a card", every "Play" button, trading and "End turn" are disabled
      And tapping a tile does not move the robber

    Scenario: Picking cards with plus and minus
      Given Cobalt is discarding 4
      When Cobalt taps "+" on timber 3 times and "+" on clay once
      Then the counter reads "4 / 4"
      And every "+" button is disabled
      And "Discard 4 cards" is enabled
      When Cobalt taps "−" on clay
      Then the counter reads "3 / 4"
      And "Discard 4 cards" is disabled

    Scenario: The minus button cannot go below zero
      Given Cobalt is discarding and has picked 0 wool
      Then the "−" button on wool is disabled

    Scenario: The plus button cannot exceed what you hold
      Given Cobalt holds 1 grain and has picked 1 grain
      Then the "+" button on grain is disabled

    Scenario: Confirming a discard
      Given Cobalt has picked 3 timber and 1 clay
      When Cobalt taps "Discard 4 cards"
      Then Cobalt loses exactly 3 timber and 1 clay
      And the log reads "Cobalt discarded 3 timber, 1 clay."
      And the header shows "Amber · discarding"
      And the discard box reads "Oh NO! Amber, the robber needs 5 cards from your deck"

    Scenario: After the last discard the roller moves the robber
      Given Amber is the last player discarding
      When Amber confirms her discard
      Then the header shows "Crimson"
      And the log reads "Crimson now moves the robber."
      And the status reads "Send in the robber! Tap a tile to move it there."

    Scenario: A 7 with nobody over 7 cards skips straight to the robber
      Given every player holds 7 cards or fewer
      When Crimson rolls 7
      Then no discard box appears
      And the status reads "Send in the robber! Tap a tile to move it there."

  # ─────────────────────────────────────────────────────────────
  Rule: Moving the robber and stealing

    Background:
      Given setup is complete
      And Crimson must move the robber

    Scenario: Choosing a tile
      Then every tile except the robber's current tile is selectable
      And the robber's current tile cannot be chosen
      When Crimson taps a numbered tile
      Then the robber is on that tile
      And that tile's number disc is marked as sitting below the robber
      And the log reads "Crimson moved the robber to H8."

    Scenario: Robber on the desert
      When the robber is on the desert
      Then the desert label is marked as sitting below the robber

    Scenario: Choosing a victim is always a visible step
      Given Cobalt has a building and 5 cards on the chosen tile
      When Crimson moves the robber there
      Then the status reads "Pick a pocket! Tap a glowing building on the robber's tile, or a name below."
      And the panel shows "Steal from Cobalt" with "5 cards"
      And Cobalt's buildings on that tile are steal targets

    Scenario Outline: Stealing by tapping
      Given Cobalt and Amber both have buildings and cards on the chosen tile
      When Crimson moves the robber there
      Then the panel shows "Steal from Cobalt" and "Steal from Amber"
      When Crimson taps <target>
      Then 1 random card moves from Cobalt to Crimson
      And the log reads "Crimson stole 1 timber from Cobalt."
      And the steal buttons disappear

      Examples:
        | target                                   |
        | Cobalt's building on that tile           |
        | the "Steal from Cobalt" button            |

    Scenario: Players are not offered as victims when they cannot be robbed
      Given the chosen tile has a Crimson settlement and an Amber settlement
      And Amber holds 0 cards
      When Crimson moves the robber there
      Then no steal step appears
      And the log reads "Nobody on that tile has cards to steal."

    Scenario: After a 7 the turn continues
      Given the robber was moved because of a 7
      When Crimson finishes stealing
      Then the status reads "The isles are yours! Build, trade, or end your turn."

  # ─────────────────────────────────────────────────────────────
  Rule: Building

    Background:
      Given setup is complete and Crimson has rolled

    Scenario Outline: Build buttons follow cost
      Given Crimson <can> afford a <piece>
      Then the "<button>" button is <state>

      Examples:
        | can    | piece      | button     | state    |
        | can    | road       | Road       | enabled  |
        | cannot | road       | Road       | disabled |
        | can    | settlement | Settlement | enabled  |
        | cannot | settlement | Settlement | disabled |
        | can    | city       | City       | enabled  |
        | cannot | city       | City       | disabled |

    Scenario: Build button toggles a mode
      When Crimson taps "Road"
      Then the "Road" button is highlighted
      And the status reads "Pave the way! Tap a dashed edge to build a road."
      When Crimson taps "Road" again
      Then no build mode is active

    Scenario: Building a road
      Given Crimson holds 1 timber and 1 clay
      When Crimson taps "Road" and taps a dashed edge
      Then a Crimson road is placed there
      And Crimson pays 1 timber and 1 clay
      And the log reads "Crimson built a road E1-2."

    Scenario: Roads must connect
      Then only edges touching a Crimson road, settlement or city are dashed

    Scenario: Roads cannot pass through an opponent's building
      Given a Crimson road ends at a corner holding a Cobalt settlement
      Then no edge beyond that corner is offered to Crimson from that road

    Scenario: Opponents' roads do not block roads
      Given a Crimson road and a Cobalt road meet at an empty corner
      Then Crimson can still build a road onward from that corner

    Scenario: Building a settlement
      Given Crimson holds 1 timber, 1 clay, 1 wool and 1 grain
      When Crimson taps "Settlement" and taps a glowing corner
      Then a Crimson settlement is placed there
      And Crimson pays 1 timber, 1 clay, 1 wool and 1 grain
      And the log reads "Crimson built a settlement at V2."

    Scenario: Settlement placement rules
      Then glowing corners are empty
      And no glowing corner is next to any building
      And every glowing corner touches a Crimson road

    Scenario: A shared crossroad is a race
      Given a Crimson road and a Cobalt road both reach an empty corner
      And no building is next to that corner
      Then both Crimson and Cobalt may settle there
      When Crimson settles there first
      Then Cobalt can no longer settle there or build a road through it

    Scenario: A crossroad next to settlements is blocked for everyone
      Given each road reaching a corner is one segment from its owner's settlement
      Then that corner does not glow for anyone

    Scenario: Upgrading to a city
      Given Crimson holds 2 grain and 3 ore
      When Crimson taps "City"
      Then Crimson's settlements are marked pulsing
      When Crimson taps one of them
      Then it becomes a city
      And Crimson pays 2 grain and 3 ore
      And the log reads "Crimson upgraded to a city at V0."

  # ─────────────────────────────────────────────────────────────
  Rule: Trading with the bank at 4 for 1

    Background:
      Given setup is complete and Crimson has rolled

    Scenario: A successful bank trade
      Given Crimson holds 4 timber
      When Crimson chooses timber to give and ore to get in "Trade with bank, 4 for 1"
      And taps "Trade 4 for 1"
      Then Crimson loses 4 timber and gains 1 ore
      And the log reads "Crimson traded 4 timber for 1 ore with the bank."

    Scenario Outline: The bank trade button is disabled when the trade is invalid
      Given <situation>
      Then "Trade 4 for 1" is disabled

      Examples:
        | situation                                       |
        | Crimson holds 3 timber and chooses to give timber |
        | Crimson chooses the same resource to give and get |
        | Crimson has not rolled yet                         |

    Scenario: The whole bank row is disabled without 4 of any resource
      Given Crimson holds 3 timber and 3 ore
      Then the bank trade row is disabled

    Scenario: The bank row is enabled with 4 of a resource
      Given Crimson holds 4 timber
      Then the bank trade row is enabled

    Scenario: The bank Give list holds only what can be traded
      Given Crimson holds 3 clay, 5 grain and 4 ore
      Then the bank Give list reads "grain, ore"

    Scenario: The bank row starts ready to trade
      Given Crimson holds 3 clay and 5 grain
      Then the bank row shows grain to give and timber to get
      And "Trade 4 for 1" is enabled

    Scenario: The bank rate never changes
      Given Crimson owns a 2:1 wool harbour
      Then the bank box still trades 4 for 1

  # ─────────────────────────────────────────────────────────────
  Rule: Trading at captured harbours

    Background:
      Given setup is complete and Crimson has rolled

    Scenario: No harbours captured
      Given Crimson has no building on any harbour corner
      Then "Your harbours" reads "None yet. Build a settlement on a corner joined to a harbour by a jetty."

    Scenario: A captured harbour is listed with what holds it
      Given Crimson has a settlement on one corner of a 3:1 harbour
      Then "Your harbours" lists "3:1 any" held by "your settlement"
      And the harbour on the board carries a Crimson ring

    Scenario: Holding both corners of a harbour
      Given Crimson has a settlement on one corner and a city on the other corner of a 2:1 grain harbour
      Then "Your harbours" lists "2:1 grain" held by "your settlement and city"

    Scenario: Several captured harbours are listed separately
      Given Crimson holds a 2:1 grain harbour and a 3:1 harbour
      Then "Your harbours" shows 2 rows, each with its own trade button

    Scenario: Trading at a 2:1 harbour
      Given Crimson holds a 2:1 wool harbour and 2 wool
      Then the give side of that row is fixed to "2 wool"
      When Crimson chooses ore to get and taps "Trade 2 for 1"
      Then Crimson loses 2 wool and gains 1 ore
      And the log reads "Crimson traded 2 wool for 1 ore at the 2:1 wool harbour (PORT 51-52)."

    Scenario: Trading at a 3:1 harbour
      Given Crimson holds a 3:1 harbour and 3 clay
      When Crimson chooses clay to give and grain to get and taps "Trade 3 for 1"
      Then Crimson loses 3 clay and gains 1 grain

    Scenario: A harbour trade button is disabled without enough cards
      Given Crimson holds a 2:1 wool harbour and 1 wool
      Then that row's "Trade 2 for 1" is disabled

    Scenario: The whole row of a 2:1 harbour is disabled without 2 of its resource
      Given Crimson holds a 2:1 wool harbour and 1 wool
      Then that harbour's trade row is disabled

    Scenario: The row of a 3:1 harbour is enabled with 3 of a resource
      Given Crimson holds a 3:1 harbour and 3 clay
      Then that harbour's trade row is enabled

    Scenario: A 3:1 harbour's Give list holds only what can be traded
      Given Crimson holds a 3:1 harbour and 3 clay
      Then that harbour's Give list reads "clay"
      And that row's "Trade 3 for 1" is enabled

    Scenario: Two players sharing a harbour
      Given Crimson holds one corner and Cobalt holds the other corner of a 3:1 harbour
      Then the harbour on the board carries a Crimson ring and a Cobalt ring
      And the harbour appears in both players' lists on their turns

  # ─────────────────────────────────────────────────────────────
  Rule: Trading with other players

    Background:
      Given setup is complete and Crimson has rolled
      And Crimson holds 3 timber, Cobalt holds 1 ore and Amber holds 1 grain

    Scenario: The offer needs a card on each side
      Then "Offer" is disabled
      When Crimson adds 2 timber to the give side
      Then "Offer" is disabled
      When Crimson adds 1 ore to the want side
      Then "Offer" is enabled

    Scenario Outline: Invalid offers cannot be sent
      Given Crimson builds an offer of <give> for <want>
      Then "Offer" is disabled

      Examples:
        | give      | want            |
        | 4 timber  | 1 ore           |
        | 1 timber  | 1 timber, 1 ore |

    Scenario: Offering to everyone
      When Crimson offers 2 timber for 1 ore
      Then the log reads "Crimson offers 2 timber for 1 ore."
      And the header shows "Cobalt · trade offer" with Cobalt's colour
      And the status reads "Crimson gives 2 timber and wants 1 ore."
      And the offer terms read "You give 1 ore and get 2 timber."
      And the hold is labelled "Cobalt's hold" and shows Cobalt's cards
      And "Accept" is enabled

    Scenario: A responder who cannot pay may only decline
      When Crimson offers 2 timber for 1 grain
      Then "Accept" is disabled with "You don't have 1 grain"
      And "Decline" is enabled

    Scenario: Responders answer one at a time in seat order
      When Crimson offers 2 timber for 1 ore
      And Cobalt taps "Decline"
      Then the log reads "Cobalt declined the offer."
      And the header shows "Amber · trade offer"
      When Amber taps "Decline"
      Then the header shows "Crimson"
      And the status reads "The answers are in! Trade with someone or withdraw."

    Scenario: Closing an accepted offer
      When Crimson offers 2 timber for 1 ore
      And Cobalt taps "Accept"
      And Amber taps "Decline"
      Then the responses list shows Cobalt "accepted" and Amber "declined"
      When Crimson taps "Trade with Cobalt"
      Then Crimson holds 1 timber and 1 ore
      And Cobalt holds 2 timber
      And the log reads "Crimson traded 2 timber with Cobalt for 1 ore."
      And the status reads "The isles are yours! Build, trade, or end your turn."

    Scenario: Withdrawing an offer
      When Crimson offers 2 timber for 1 ore
      And Cobalt taps "Decline"
      And Amber taps "Decline"
      And Crimson taps "Withdraw"
      Then every hand is unchanged
      And the log reads "Crimson withdrew the offer."

    Scenario: An offer nobody can answer
      Given Cobalt holds 0 cards and Amber holds 0 cards
      When Crimson offers 2 timber for 1 ore
      Then the log reads "Nobody can answer that offer."
      And the status reads "The isles are yours! Build, trade, or end your turn."

    Scenario: An offer to one seat asks only that seat
      When Crimson offers 2 timber for 1 ore to Amber
      Then the log reads "Crimson offers 2 timber for 1 ore to Amber."
      And the header shows "Amber · trade offer"

    Scenario: A counter-offer is shown and can be taken
      Given Crimson offered 2 timber for 1 ore
      And Cobalt countered with 3 timber for 1 ore
      And Amber declined
      Then the responses list shows Cobalt "countered: 3 timber for 1 ore"
      When Crimson taps "Trade with Cobalt"
      Then Crimson holds 0 timber and 1 ore
      And the log reads "Crimson traded 3 timber with Cobalt for 1 ore."

  # ─────────────────────────────────────────────────────────────
  Rule: The bank can run out

    Background:
      Given setup is complete
      And it is Crimson's turn and Crimson has not rolled

    Scenario: The bank row shows the supply
      Then the bank row shows 19 of each resource

    Scenario: One player owed a short resource takes what is left
      Given the bank holds 1 ore
      And Amber has a city on a tile numbered 8 producing ore
      When Crimson rolls 8
      Then Amber receives 1 ore
      And the bank holds 0 ore
      And the log reads "Bank is out of ore."

    Scenario: Two players owed a short resource get nothing
      Given the bank holds 1 ore
      And Cobalt and Amber each have a settlement on a tile numbered 8 producing ore
      When Crimson rolls 8
      Then Cobalt and Amber receive no ore
      And the bank holds 1 ore
      And the log reads "Bank is out of ore."

    Scenario: Trades cannot take what the bank lacks
      Given Crimson has rolled and holds 4 timber
      And the bank holds 0 ore
      When Crimson chooses timber to give and ore to get in "Trade with bank, 4 for 1"
      Then "Trade 4 for 1" is disabled

    Scenario: Bumper harvest cannot take what the bank lacks
      Given Crimson has rolled and holds a playable Bumper harvest
      And the bank holds 1 ore
      Then Crimson cannot choose ore and ore
      But Crimson can choose grain and ore

  # ─────────────────────────────────────────────────────────────
  Rule: Piece limits

    Background:
      Given setup is complete and Crimson has rolled

    Scenario: The build and card buttons show what they cost
      Then the "Road" button costs 1 timber and 1 clay
      And the "Settlement" button costs 1 timber, 1 clay, 1 wool and 1 grain
      And the "City" button costs 2 grain and 3 ore
      And the "Buy a card" button costs 1 wool, 1 grain and 1 ore

    Scenario: Build buttons show how many pieces are left
      Given Crimson has the 2 settlements and 2 roads from setup on the board
      Then the "Settlement" button shows "3 left"
      And the "City" button shows "4 left"
      And the "Road" button shows "13 left"

    Scenario: The sixth settlement is not offered
      Given Crimson has 5 settlements on the board and can afford a settlement
      Then the "Settlement" button shows "0 left"
      And the "Settlement" button is disabled

    Scenario: A city frees a settlement piece
      Given Crimson has 5 settlements on the board and can afford a city
      When Crimson upgrades one of them to a city
      Then the "Settlement" button shows "1 left"

    Scenario: Road crew with one road piece left
      Given Crimson has 14 roads on the board and holds a playable Road crew
      When Crimson plays Road crew and places one free road
      Then the log reads "No roads left to build."
      And the status reads "The isles are yours! Build, trade, or end your turn."

  # ─────────────────────────────────────────────────────────────
  Rule: Development cards

    Background:
      Given setup is complete

    Scenario: Buying a card
      Given Crimson has rolled and holds 1 wool, 1 grain and 1 ore
      When Crimson taps "Buy a card"
      Then Crimson pays 1 wool, 1 grain and 1 ore
      And Crimson gains 1 development card
      And the deck count on the button drops by 1
      And the log reads "Crimson bought a development card: Victory point."

    Scenario Outline: Buying is disabled when not allowed
      Given <situation>
      Then "Buy a card" is disabled

      Examples:
        | situation                                  |
        | Crimson has not rolled                     |
        | Crimson cannot afford wool, grain and ore  |
        | the deck is empty                          |

    Scenario: A card cannot be played on the turn it was bought
      Given Crimson bought a Knight this turn
      Then that card's "Play" button is disabled
      And the card notes "bought this turn"

    Scenario: Only one card can be played per turn
      Given Crimson has played a development card this turn
      Then every other card's "Play" button is disabled
      And those cards note "one card per turn"

    Scenario: A Knight may be played before rolling
      Given Crimson has not rolled and holds a Knight bought on an earlier turn
      Then that Knight's "Play" button is enabled

    Scenario: Other cards need the roll first
      Given Crimson has not rolled and holds a Bumper harvest bought on an earlier turn
      Then that card's "Play" button is disabled

    Scenario: Playing a Knight before rolling
      Given Crimson has not rolled and holds a playable Knight
      When Crimson taps "Play" on the Knight
      Then the Knight leaves Crimson's cards
      And Crimson's "Knights" badge increases by 1
      And the log reads "Crimson played a Knight."
      And no discard step happens
      And the status reads "Send in the robber! Tap a tile to move it there."
      And "Roll dice" is disabled
      When Crimson moves the robber and steals
      Then the status reads "Your move, captain. Roll the dice!"
      And "Roll dice" is enabled

    Scenario: Playing a Knight after rolling
      Given Crimson has rolled and holds a playable Knight
      When Crimson plays the Knight, moves the robber and steals
      Then the status reads "The isles are yours! Build, trade, or end your turn."

    Scenario: Victory point cards
      Given Crimson draws a victory point card
      Then the card shows "counts automatically" and has no "Play" button
      And Crimson's score shows "+1" only while it is Crimson's turn
      And other players' views do not show Crimson's hidden point

    Scenario: Road crew
      Given Crimson has rolled and holds a playable Road crew
      When Crimson taps "Play" on it
      Then the status reads "Road crew on the job! Tap a dashed edge for a free road (2 left)."
      And building, trading and ending the turn are disabled
      When Crimson taps 2 dashed edges
      Then 2 Crimson roads are placed without paying
      And the log twice reads a line starting "Crimson built a free road E"
      And the status reads "The isles are yours! Build, trade, or end your turn."

    Scenario: Road crew with no room
      Given Crimson has no legal edge to build on
      When Crimson plays Road crew
      Then the log reads "No room for new roads."

    Scenario: Bumper harvest
      Given Crimson has rolled and holds a playable Bumper harvest
      When Crimson chooses ore and ore and taps "Play"
      Then Crimson gains 2 ore
      And the log reads "Crimson played Bumper harvest: ore and ore."

    Scenario: Corner the market
      Given Crimson has rolled and holds a playable Corner the market
      And Cobalt holds 3 ore and Amber holds 2 ore
      When Crimson chooses ore and taps "Play"
      Then Crimson gains 5 ore
      And Cobalt and Amber hold 0 ore
      And the log reads "Crimson cornered the ore market and took 5 (Cobalt 3, Amber 2)."

  # ─────────────────────────────────────────────────────────────
  Rule: Longest road

    Background:
      Given setup is complete

    Scenario: Claiming longest road
      When Crimson's longest continuous road reaches 5 segments and nobody holds the award
      Then Crimson holds longest road
      And Crimson's "Road" badge is highlighted
      And Crimson gains 2 points
      And the log reads "Crimson takes longest road (5)."

    Scenario: A branching road counts one path
      Given Crimson has 3 roads meeting at one corner in a Y shape
      Then Crimson's "Road" badge shows 2

    Scenario: A tie does not take the award
      Given Crimson holds longest road with 6 segments
      When Cobalt's road reaches 6 segments
      Then Crimson still holds longest road

    Scenario: Beating the holder takes the award
      Given Crimson holds longest road with 6 segments
      When Cobalt's road reaches 7 segments
      Then Cobalt holds longest road
      And Crimson loses 2 points

    Scenario: An opponent's settlement cuts the road
      Given Crimson holds longest road with a 6-segment road
      When Cobalt builds a settlement in the middle of it, leaving 3 and 3
      Then Crimson's "Road" badge shows 3
      And nobody holds longest road
      And the log reads "Nobody holds longest road now."

    Scenario: Holder is cut and two others tie
      Given Crimson holds longest road
      And Cobalt and Amber both have 6-segment roads
      When Crimson's road is cut below 6
      Then nobody holds longest road

  # ─────────────────────────────────────────────────────────────
  Rule: Largest army

    Background:
      Given setup is complete

    Scenario: Claiming largest army
      When Crimson plays a third Knight and nobody holds the award
      Then Crimson holds largest army
      And Crimson's "Knights" badge is highlighted
      And Crimson gains 2 points
      And the log reads "Crimson takes largest army (3 knights)."

    Scenario: A tie does not take the award
      Given Crimson holds largest army with 3 Knights
      When Cobalt plays a third Knight
      Then Crimson still holds largest army

    Scenario: Beating the holder takes the award
      Given Crimson holds largest army with 3 Knights
      When Cobalt plays a fourth Knight
      Then Cobalt holds largest army

  # ─────────────────────────────────────────────────────────────
  Rule: Scoreboard

    Scenario: Each player's row
      Given setup is complete
      Then each player row shows their colour, name, card count and development card count
      And a "Road N" badge with their longest road length
      And a "Knights N" badge with their Knights played
      And a score "N / 10" counting buildings and awards only
      And a "+N" for hidden victory points, shown only on the current player's row

  # ─────────────────────────────────────────────────────────────
  Rule: Winning

    Background:
      Given setup is complete

    Scenario Outline: Reaching 10 points on your own turn wins immediately
      Given Crimson has <start> points
      When Crimson <action>
      Then Crimson wins

      Examples:
        | start | action                                                  |
        | 9     | builds a settlement                                     |
        | 9     | builds a city                                           |
        | 8     | builds a road that takes longest road                   |
        | 8     | plays a third Knight and takes largest army             |
        | 9     | buys a victory point card                               |

    Scenario: Hidden victory point cards count
      Given Crimson has 8 public points and 2 victory point cards
      When the win check runs on Crimson's turn
      Then Crimson wins
      And the log reads "Crimson wins with 10 points, including 2 hidden victory point cards!"
      And the banner reads "Crimson rules the isles with 10 points."

    Scenario: A passive win is caught at the start of the turn
      Given Crimson has 8 points and a 6-segment road
      And Amber holds longest road with a 7-segment road
      And it is Cobalt's turn
      When Cobalt builds a settlement that cuts Amber's road below 6
      Then Crimson holds longest road and has 10 points
      But Crimson has not won yet, because it is Cobalt's turn
      When Cobalt ends the turn
      Then Crimson wins at the start of Crimson's turn

    Scenario: The game locks after a win
      Given Crimson has won
      Then the status reads "That's the game!"
      And every action button is disabled
      And the board stays visible

  # ─────────────────────────────────────────────────────────────
  Rule: Victory screen

    Scenario: The win screen plays
      When Crimson wins
      Then the victory card is showing
      And the card carries Crimson's colour
      And it reads "Victory" and "Crimson wins"
      And it shows "Rules the isles after N rounds."
      And the breakdown lists only sources worth more than 0, then the total
      And the confetti schedule has a centre burst, two corner cannons and a second wave 0.55 seconds later
      And Crimson's settlements and cities are marked as the champion's

    Scenario: Closing the win screen
      Given the victory screen is showing
      When I tap "See the board"
      Then the overlay closes
      And the winner's pieces stay marked as the champion's

    @ui
    Scenario: Escape closes the win screen
      Given the victory screen is showing
      When I press Escape
      Then the overlay closes

    @ui
    Scenario: The win screen is hidden at load
      When the app launches
      Then the victory screen is hidden

    Scenario: Previewing the win screen
      Given setup is complete and it is Cobalt's turn
      When I tap "Preview win"
      Then the overlay reads "Preview" and "Cobalt wins"
      And it reads "This is what the win screen looks like. The game carries on."
      And "New game" is not offered
      When I tap "Back to the game"
      Then the overlay closes and the game continues unchanged

    Scenario: Reduce Motion
      Given the device has Reduce Motion turned on
      When a player wins
      Then the victory card appears without confetti or animation

  # ─────────────────────────────────────────────────────────────
  Rule: Ending the turn

    Scenario: Passing the dice
      Given setup is complete and Crimson has rolled
      And no discard, robber move, steal or free road is pending
      When Crimson taps "End turn"
      Then it is Cobalt's turn
      And both dice show "–"
      And any build mode is cleared
      And Cobalt may play a development card this turn

    Scenario: End turn is locked until the roll
      Given it is Crimson's turn and Crimson has not rolled
      Then "End turn" is disabled

  # ─────────────────────────────────────────────────────────────
  Rule: Handing the device to another human

    Scenario: Ending a turn hides the game until the next human is ready
      Given setup is complete and Crimson has rolled
      And Crimson has the device
      When Crimson taps "End turn"
      Then the handover reads "Eyes off! Pass the device to Cobalt" with the button "Start turn, Cobalt"
      When the handover button is tapped
      Then no handover is shown
      And the hold is labelled "Cobalt's hold"

    Scenario: The human holding the device sees no handover
      Given setup is complete and Crimson has rolled
      And Crimson has the device
      Then no handover is shown

    Scenario: A human who must discard gets the device privately
      Given setup is complete and it is Crimson's turn
      And Crimson holds 3 cards, Cobalt holds 8 cards and Amber holds 3 cards
      When Crimson rolls 7
      Then the handover reads "Eyes off! Pass the device to Cobalt" with the button "Discard, Cobalt"

    Scenario: A trade offer goes to each human privately and comes back
      Given setup is complete and Crimson has rolled
      And Crimson holds 3 timber, Cobalt holds 1 ore and Amber holds 1 grain
      When Crimson offers 2 timber for 1 ore
      Then the handover reads "Eyes off! Pass the device to Cobalt" with the button "See the offer, Cobalt"
      When the handover button is tapped
      And Cobalt taps "Decline"
      Then the handover reads "Eyes off! Pass the device to Amber" with the button "See the offer, Amber"
      When the handover button is tapped
      And Amber taps "Decline"
      Then the handover reads "Eyes off! Pass the device to Crimson" with the button "Continue, Crimson"

    Scenario: With one human no handover ever appears
      Given a 3-player game with Crimson human and the others AI
      When the AI seats have finished acting
      Then no handover is shown

    Scenario: An AI needs no handover
      Given a 3-player game with Crimson and Cobalt human and Amber AI
      When Amber is thinking
      Then no handover is shown

    Scenario: No handover during the first roll
      Then no handover is shown

    Scenario: No handover at the end of the game
      When a player wins
      Then no handover is shown

    Scenario: Reopening the game hides it until someone is ready
      Given setup is complete and Crimson has rolled
      And Crimson has the device
      When the game is reopened
      Then the handover reads "Eyes off! Pass the device to Crimson" with the button "Continue, Crimson"

    Scenario: Leaving the app hides the game until someone is ready
      Given setup is complete and Crimson has rolled
      And Crimson has the device
      When the app goes to the background
      Then the handover reads "Eyes off! Pass the device to Crimson" with the button "Continue, Crimson"

  # ─────────────────────────────────────────────────────────────
  Rule: Playing against AI seats

    Scenario: Choosing seats for a new game
      When I start a 3-player game with Crimson human, Cobalt an AI Mate and Amber an AI Admiral
      Then the players are Crimson, Cobalt and Amber
      And Cobalt and Amber are AI seats
      And the log contains "Crimson is human."
      And the log contains "Cobalt is an AI Mate."
      And the log contains "Amber is an AI Admiral."

    Scenario: A searching seat says how hard it thought
      When I start a 3-player game with Crimson human, Cobalt an AI Captain and Amber an AI Captain
      And the first-player rolls are Crimson 8, Cobalt 5 and Amber 3
      And the AI seats have finished acting
      And Crimson taps a glowing corner
      And Crimson taps a dashed edge
      And the AI seats have finished acting
      Then the log has a line starting "Cobalt weighed"
      And the log has a line starting "Amber weighed"

    Scenario: AI seats take their turns by themselves
      Given a 3-player game with Crimson human and the others AI
      When the AI seats have finished acting
      Then it is Crimson who must act
      And the status does not read "Cobalt is plotting…"

    Scenario: Controls are locked while an AI acts
      Given a 3-player game with Crimson human and the others AI
      When Cobalt is thinking
      Then the status reads "Cobalt is plotting…"
      And every action button is disabled

    Scenario: One human keeps seeing their hand during AI turns
      Given a 3-player game with Crimson human and the others AI
      When Cobalt is thinking
      Then the hold is labelled "Crimson's hold"

    Scenario: With two humans no hand shows during AI turns
      Given a 3-player game with Crimson and Cobalt human and Amber AI
      When Amber is thinking
      Then no hand is shown

    Scenario: An AI never shows hidden points
      Given a 3-player game with Crimson human and the others AI
      And Cobalt holds a victory point card and it is Cobalt's turn
      Then Cobalt's row shows no "+N"

    Scenario: An AI answers an offer at once
      Given a 3-player game with Crimson human and the others AI
      And setup is complete and Crimson has rolled
      And Crimson holds 2 timber and Cobalt holds 1 ore
      When Crimson offers 2 timber for 1 ore to Cobalt
      Then Cobalt's answer is in without passing the device
      And the header shows "Crimson"

    Scenario: A human answers an AI's offer
      Given a 3-player game with Crimson human and the others AI
      And Cobalt has offered 1 ore for 1 timber to Crimson
      Then the header shows "Crimson · trade offer"
      And the status reads "Cobalt gives 1 ore and wants 1 timber."
      And the offer terms read "You give 1 timber and get 1 ore."
      And the hold is labelled "Crimson's hold" and shows Crimson's cards
      And "Accept" and "Decline" are offered

  Rule: Saving and loading games
    Up to 5 named saves. The automatic game that reopens with the app is separate and does not count.

    Scenario: Saving keeps a copy under its name
      Given setup is complete and Crimson has rolled
      When I save the game as "Before the robber"
      Then the saves list "Before the robber"
      And the game on the board is the one that was saved

    Scenario: Loading brings a saved game back
      Given setup is complete and Crimson has rolled
      When I save the game as "Good position"
      And the game moves on a turn
      And I load the save called "Good position"
      Then the game on the board is the one that was saved

    Scenario: A sixth save is refused rather than deleting one
      Given setup is complete and Crimson has rolled
      And all 5 saves are used
      When I save the game as "Sixth"
      Then the save is refused
      And there are 5 saves
      And the saves do not list "Sixth"

    Scenario: With all 5 used, the player picks which save to replace
      Given setup is complete and Crimson has rolled
      And all 5 saves are used
      When I save the game as "Newest" over "Save 2"
      Then there are 5 saves
      And the saves list "Newest"
      And the saves do not list "Save 2"

    Scenario: A save that crashed the last launch is set aside
      Given setup is complete and Crimson has rolled
      And the last launch died while resuming the game
      When the app is relaunched
      Then no game is on the board
      And the crashed game is kept aside for a replay

    Scenario: Deleting a save makes room
      Given setup is complete and Crimson has rolled
      And all 5 saves are used
      When I delete the save called "Save 3"
      And I save the game as "Room at last"
      Then there are 5 saves
      And the saves list "Room at last"
      And the saves do not list "Save 3"

    Scenario: A blank name is refused
      Given setup is complete and Crimson has rolled
      When I save the game as "   "
      Then the save is refused
      And there are 0 saves

    Scenario: A finished game cannot be saved
      Given the game has ended
      Then saving is not offered
