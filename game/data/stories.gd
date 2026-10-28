class_name Stories
## Career story text: the monthly rivalries and the one-off moments (debut, new team,
## title changes), told as short promo scenes. A beat is a list of [speaker, line];
## speakers are "host" (the backstage interviewer, caption only), "you", "rival",
## "partner", "champ" or "contender". Lines fill in {you} {rival} {partner} {champ}
## {contender} {tag_champs} {ppv} {show}, and {you_brag} / {rival_brag} (catchphrases).

const HOST := "DALE SPURLOCK"

## Catchphrases; created wrestlers use DEFAULT_BRAG.
const BRAGS := {
	"thunder_mack": "When the thunder rolls in off South Street, you'd better find some shelter!",
	"zip_volta": "A hundred thousand volts, and every last one of them has your name on it!",
	"bruno_kessler": "Nobody gets past the Iron Wall. Nobody.",
	"quetzal_neon": "The wings of the quetzal fly higher than you will ever climb, amigo!",
	"silas_wren": "I've seen every move you'll make, three moves before you make it.",
	"kai_breakwater": "I paddle out into bigger trouble than you every morning, dude.",
	"overclock": "Scanning... threat level: negligible. Victory probability: one hundred percent.",
	"nova_reyes": "Look up. That's where I'll be when you're flat on your back.",
	"roxy_ravage": "Crank it up and hold on tight, because the hurricane doesn't knock!",
	"mister_midnight": "Count to twelve. Then the lights go out.",
}
const DEFAULT_BRAG := "Nobody is stopping me now. NOBODY!"

## Monthly rivalries away from the title picture: start (first show of the month),
## build (third show), ppv (before the pay-per-view grudge match), win / loss (after it).
const RIVALRIES := {
	"jealousy": {
		"start": [["host", "{you}, you've been on a roll, and not everybody's happy about it. {rival}, you wanted a word?"],
			["rival", "I've paid my dues in this company for YEARS. And who gets the spotlight? {you}!"],
			["rival", "Not anymore. I'm taking back what's mine."],
			["you", "{you_brag}"]],
		"build": [["host", "Earlier tonight somebody spray-painted {you}'s locker. Three words: SEE YOU AT {ppv}."],
			["you", "{rival}, you want my spot? Then stop hiding behind a spray can."],
			["you", "{ppv}. No disqualifications. Come and take it."]],
		"ppv": [["host", "It's been building all month. {rival}, any last words before tonight's grudge match?"],
			["rival", "{rival_brag}"]],
		"win": [["host", "{you} has put {rival} right back where they started!"],
			["you", "Back of the line, {rival}. And stay there."]],
		"loss": [["rival", "Told you, {you}. Some of us EARNED it."],
			["host", "A bitter night for {you}. The climb goes on."]],
	},
	"ambush": {
		"start": [["host", "We're getting reports from the parking lot... {you} has been jumped from behind!"],
			["rival", "Nothing personal, {you}. Just business. You were in my way."],
			["you", "You picked the wrong fight, {rival}. I'll see you in the ring."]],
		"build": [["host", "{you} has demanded a match with {rival} at {ppv}, no rules, and the office has said YES!"],
			["rival", "No rules suits me fine. I've never needed them anyway."]],
		"ppv": [["host", "No disqualifications tonight. {you}, is it payback time?"],
			["you", "{rival} started this in a parking lot. I'm finishing it in front of the whole world."]],
		"win": [["host", "Payback is complete! {you} got the last word!"],
			["you", "Next time you come at me, {rival}, you'd better come from the front."]],
		"loss": [["rival", "Same result as the parking lot. Get used to it."],
			["host", "{rival} has the upper hand... for now."]],
	},
	"respect": {
		"start": [["host", "{rival}, you asked to speak with {you} face to face."],
			["rival", "I've watched you climb, {you}. Fast. Maybe too fast."],
			["rival", "So let's find out if you're the real deal. {ppv}, you and me."],
			["you", "You've got yourself a match. Bring your best."]],
		"build": [["host", "{you}, {rival} says that last week's win was luck."],
			["you", "Then {rival} can watch closely at {ppv}. Luck doesn't do THIS twice."]],
		"ppv": [["host", "Two of the best in the world tonight. Any words for {rival}?"],
			["you", "Win or lose, I'll shake your hand after. But I'm going to win."]],
		"win": [["rival", "That was no fluke. You earned that, {you}."],
			["you", "Means a lot coming from you. Any time you want a rematch."]],
		"loss": [["rival", "You've got a future, kid. Just not tonight."],
			["you", "Good match. We're running this back someday."]],
	},
	"mind_games": {
		"start": [["host", "{you}, this package arrived for you backstage. An hourglass... and a note."],
			["host", "It says: 'Your time is running out.' Signed... {rival}."],
			["you", "{rival} thinks they can get in my head? Good luck finding anything up there to scare."]],
		"build": [["host", "The lights in the arena went out for ten seconds tonight. When they came back..."],
			["rival", "...I was standing right behind you, {you}. I could have done anything."],
			["rival", "At {ppv}, I will."]],
		"ppv": [["host", "{rival} has been playing games all month. Are you rattled?"],
			["you", "The games stop tonight, {rival}. It's just you and me in that ring."]],
		"win": [["host", "{you} kept their cool and beat {rival} at their own game!"],
			["you", "Keep the hourglass. I've got all the time in the world."]],
		"loss": [["rival", "Tick... tock... I told you, {you}. Your time ran out."],
			["host", "{rival}'s mind games paid off tonight."]],
	},
	"spotlight": {
		"start": [["host", "Last week {rival} came out to {you}'s music, wearing {you}'s colours!"],
			["rival", "The fans liked it better when I did it. Face it, {you}: I do you better than you."],
			["you", "There's only one me, {rival}. And I'll prove it."]],
		"build": [["host", "{rival} has challenged {you} to a match at {ppv}. Winner keeps the spotlight."],
			["rival", "{rival_brag}"],
			["you", "{you_brag}"]],
		"ppv": [["host", "The crowd can only cheer for one of you tonight. Who's it going to be?"],
			["you", "Listen to them, {rival}. They already know."]],
		"win": [["host", "The spotlight belongs to {you}!"],
			["you", "Get your own act, {rival}."]],
		"loss": [["rival", "Did you hear that pop? That was for ME."],
			["host", "{rival} steals the show... and the spotlight."]],
	},
}

## The World title picture: you as challenger, or as champion.
const TITLE := {
	"title_chase": {
		"start": [["host", "{you}, you're the number one contender! At {ppv} you face {champ} for the World title."],
			["champ", "The number one contender? I've beaten better before breakfast."],
			["champ", "{rival_brag}"],
			["you", "Enjoy that belt while you can, {champ}. It's coming home with me."]],
		"build": [["host", "{champ} hasn't lost in months. What makes you think you're different?"],
			["you", "Every champion loses eventually. {ppv} is when {champ}'s run ends."]],
		"ppv": [["host", "This is it. The World Heavyweight Championship. Anything to say?"],
			["you", "I've been climbing for this my whole life. Tonight I reach the top."]],
		"win": [["host", "AND THE NEW... WORLD... HEAVYWEIGHT... CHAMPION... {you}!!!"],
			["you", "THIS IS MY TIME! This belt is for everybody who believed in me!"]],
		"loss": [["champ", "And STILL champion. Back to the bottom of the mountain, {you}."],
			["host", "So close for {you}. Win your way back to number one and you'll get another shot."]],
	},
	"title_defence": {
		"start": [["host", "{you}, your challenger at {ppv} is the number one contender, {contender}."],
			["contender", "That gold looks better around my waist, {you}."],
			["contender", "{rival_brag}"],
			["you", "Then come and take it. Plenty have tried."]],
		"build": [["host", "{contender} has been studying tapes of every one of your matches, champ."],
			["you", "Let them study. Tapes don't hit back."]],
		"ppv": [["host", "Your title is on the line tonight, champ."],
			["you", "Nobody is taking this belt from me. Not tonight, not ever."]],
		"win": [["host", "AND STILL... THE WORLD HEAVYWEIGHT CHAMPION... {you}!"],
			["you", "Who's next? Line them up!"]],
		"loss": [["host", "WE HAVE A NEW CHAMPION! {contender} has done it!"],
			["contender", "I told you, {you}. It looks better on me."]],
	},
}

## One-off moments.
const MOMENTS := {
	"debut": [["host", "Welcome to {show}! Tonight, a brand new face makes their debut: {you}!"],
		["you", "{you_brag}"],
		["host", "Win matches to climb the rankings. Be number one at the start of the month, and you get a shot at {champ} and the World title!"]],
	"partner": [["partner", "Hey, {you}. Singles is a long road. You want some company on it?"],
		["partner", "You and me, as a team. We go after the tag titles."],
		["you", "Let's do it, partner."],
		["host", "A new team! Win two tag matches and you'll get a shot at the champions: {tag_champs}."]],
	"tag_won": [["host", "AND THE NEW TAG TEAM CHAMPIONS... {you} AND {partner}!!!"],
		["partner", "We did it, partner! We're the best team in the world!"]],
	"tag_lost": [["host", "The tag titles have changed hands!"],
		["partner", "We'll get them back, {you}. Two more wins and we're right back in it."]],
	"hall_of_fame": [["host", "Three successful title defences. {you}, you are a living legend."],
		["host", "When your career is over, there's a place waiting for you in the Hall of Fame."],
		["you", "I'm not done yet. Not even close!"]],
}


static func brag(id: String) -> String:
	return BRAGS.get(id, DEFAULT_BRAG)
