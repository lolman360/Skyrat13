/mob
	datum_flags = DF_USE_TAG
	density = TRUE
	layer = MOB_LAYER
	animate_movement = 2
	flags_1 = HEAR_1
	hud_possible = list(ANTAG_HUD)
	pressure_resistance = 8
	mouse_drag_pointer = MOUSE_ACTIVE_POINTER
	throwforce = 10
	//blocks_emissive = EMISSIVE_BLOCK_GENERIC // Skyrat edit -- 512 compatibility

	//vis_flags = VIS_INHERIT_PLANE //when this be added to vis_contents of something it inherit something.plane, important for visualisation of mob in openspace. // Skyrat edit -- 512 compatibility

	/// What receives our keyboard input. src by default.
	var/datum/focus

	var/lighting_alpha = LIGHTING_PLANE_ALPHA_VISIBLE
	var/datum/mind/mind
	var/list/datum/action/actions = list()
	var/list/datum/action/chameleon_item_actions
	var/static/next_mob_id = 0

	var/stat = CONSCIOUS //Whether a mob is alive or dead. TODO: Move this to living - Nodrak

	/*A bunch of this stuff really needs to go under their own defines instead of being globally attached to mob.
	A variable should only be globally attached to turfs/objects/whatever, when it is in fact needed as such.
	The current method unnecessarily clusters up the variable list, especially for humans (although rearranging won't really clean it up a lot but the difference will be noticable for other mobs).
	I'll make some notes on where certain variable defines should probably go.
	Changing this around would probably require a good look-over the pre-existing code.
	*/
	var/zone_selected = BODY_ZONE_CHEST

	var/computer_id = null
	var/list/logging = list()
	var/atom/machine = null

	var/next_move = null
	var/create_area_cooldown
	/// Whether or not the mob is currently being transformed into another mob or into another state of being. This will prevent it from moving or doing realistically anything.
	/// Don't you DARE use this for a cheap way to ensure someone is stunned in your code.
	var/mob_transforming = FALSE
	var/eye_blind = 0		//Carbon
	var/eye_blurry = 0		//Carbon
	var/real_name = null
	var/spacewalk = FALSE
	var/resting = 0			//Carbon
	var/lying = 0
	var/lying_prev = 0
	var/is_shifted = FALSE

	/// List of movement speed modifiers applying to this mob
	var/list/movespeed_modification				//Lazy list, see mob_movespeed.dm
	/// List of movement speed modifiers ignored by this mob. List -> List (id) -> List (sources)
	var/list/movespeed_mod_immunities			//Lazy list, see mob_movespeed.dm
	/// The calculated mob speed slowdown based on the modifiers list
	var/cached_multiplicative_slowdown
	/////////////////

	var/name_archive //For admin things like possession

	var/bodytemperature = BODYTEMP_NORMAL	//310.15K / 98.6F
	var/drowsyness = 0//Carbon
	var/dizziness = 0//Carbon
	var/jitteriness = 0//Carbon
	var/nutrition = NUTRITION_LEVEL_START_MIN // randomised in Initialize
	var/satiety = 0//Carbon

	var/overeatduration = 0		// How long this guy is overeating //Carbon
	var/a_intent = INTENT_HELP//Living
	var/list/possible_a_intents = null//Living
	var/m_intent = MOVE_INTENT_RUN//Living
	var/lastKnownIP = null
	var/atom/movable/buckled = null//Living
	var/atom/movable/buckling

	//Hands
	var/active_hand_index = 1
	var/list/held_items = list() //len = number of hands, eg: 2 nulls is 2 empty hands, 1 item and 1 null is 1 full hand and 1 empty hand.
	//held_items[active_hand_index] is the actively held item, but please use get_active_held_item() instead, because OOP
	var/bloody_hands = 0

	var/datum/component/storage/active_storage = null//Carbon

	var/datum/hud/hud_used = null

	var/research_scanner = 0 //For research scanner equipped mobs. Enable to show research data when examining.

	var/in_throw_mode = 0

	var/job = null//Living

	var/list/faction = list("neutral") //A list of factions that this mob is currently in, for hostile mob targetting, amongst other things
	var/move_on_shuttle = 1 // Can move on the shuttle.

	/// The last mob/living/carbon to push/drag/grab this mob (mostly used by slimes friend recognition)
	var/datum/weakref/LAssailant

	var/list/mob_spell_list = list() //construct spells and mime spells. Spells that do not transfer from one mob to another and can not be lost in mindswap.


	var/status_flags = CANSTUN|CANKNOCKDOWN|CANUNCONSCIOUS|CANPUSH	//bitflags defining which status effects can be inflicted (replaces canknockdown, canstun, etc)

	var/digitalcamo = 0 // Can they be tracked by the AI?
	var/digitalinvis = 0 //Are they ivisible to the AI?
	var/image/digitaldisguise = null  //what does the AI see instead of them?

	var/silicon_privileges = NONE // Can they interact with station electronics

	var/obj/control_object //Used by admins to possess objects. All mobs should have this var
	var/atom/movable/remote_control //Calls relaymove() to whatever it is

	/**
	  * The sound made on death
	  *
	  * leave null for no sound. used for *deathgasp
	  */
	var/deathsound = null

	var/turf/listed_turf = null	//the current turf being examined in the stat panel

	var/list/observers = null	//The list of people observing this mob.

	var/list/progressbars = null	//for stacking do_after bars

	///For storing what do_after's someone has, in case we want to restrict them to only one of a certain do_after at a time
	var/list/do_afters

	var/list/mousemove_intercept_objects

	var/datum/click_intercept

	var/registered_z

	var/list/alerts = list() // contains /obj/screen/alert only // On /mob so clientless mobs will throw alerts properly
	var/list/screens = list()
	var/list/client_colours = list()
	var/hud_type = /datum/hud

	var/datum/hSB/sandbox = null

	var/mob/audiovisual_redirect //Mob to redirect messages, speech, and sounds to

	var/siliconaccessareas = list()
	var/siliconaccesstoggle = FALSE

	var/voluntary_ghosted = FALSE		//whether or not they voluntarily ghosted.

	var/has_field_of_vision = FALSE
	var/field_of_vision_type = FOV_90_DEGREES


	///////TYPING INDICATORS///////
	/// Set to true if we want to show typing indicators.
	var/typing_indicator_enabled = FALSE
	/// Default icon_state of our typing indicator. Currently only supports paths (because anything else is, as of time of typing this, unnecesary.
	var/typing_indicator_state = /obj/effect/overlay/typing_indicator
	/// The timer that will remove our indicator for early aborts (like when an user finishes their message)
	var/typing_indicator_timerid
	/// Current state of our typing indicator. Used for cut overlay, DO NOT RUNTIME ASSIGN OTHER THAN FROM SHOW/CLEAR. Used to absolutely ensure we do not get stuck overlays.
	var/typing_indicator_current
