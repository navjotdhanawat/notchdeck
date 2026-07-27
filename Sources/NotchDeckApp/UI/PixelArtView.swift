import SwiftUI
import NotchDeckCore

public enum AnimationTheme: String, CaseIterable, Identifiable {
    case lego, pacman, pokemon, mario, space

    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .lego: return "Lego Builder"
        case .pacman: return "Retro Arcade"
        case .pokemon: return "Pocket Monsters"
        case .mario: return "Super Mario"
        case .space: return "Space Invaders"
        }
    }
}

struct PixelSprite {
    let width: Int
    let height: Int
    let frames: [[String]]
}

enum PixelSprites {
    // MARK: - Lego Builder Theme Sprites
    static let robotDeveloper = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Robot neutral
            [
                "............",
                "...BTTTTB...",
                "..BTYYYYTB..",
                "..BTY..YTB..",
                "..BTYYYYTB..",
                "...BBBBBB...",
                "..BPPPPPPB..",
                ".BPPPPPPPPB.",
                ".BPPBBBBPPB.",
                "SSBBBBBBBBSS",
                "............",
                "............"
            ],
            // Frame 2: Left hand coding
            [
                "............",
                "...BTTTTB...",
                "..BTYYYYTB..",
                "..BTY..YTB..",
                "..BTYYYYTB..",
                "...BBBBBB...",
                "..BPPPPPPB..",
                ".BPPP.PPPPB.",
                "PBPPBBBBPPB.",
                "SSBBBBBBBBSS",
                "............",
                "............"
            ],
            // Frame 3: Right hand coding
            [
                "............",
                "...BTTTTB...",
                "..BTYYYYTB..",
                "..BTY..YTB..",
                "..BTYYYYTB..",
                "...BBBBBB...",
                "..BPPPPPPB..",
                ".BPPPP.PPBP.",
                ".BPPBBBBPPB.",
                "SSBBBBBBBBSS",
                "............",
                "............"
            ],
            // Frame 4: Typing fast
            [
                "............",
                "...BTTTTB...",
                "..BTYYYYTB..",
                "..BTY..YTB..",
                "..BTYYYYTB..",
                "...BBBBBB...",
                "..BPPPPPPB..",
                "PPPPPPPPPPPP",
                ".BPPBBBBPPB.",
                "SSBBBBBBBBSS",
                "............",
                "............"
            ]
        ]
    )

    static let legoBuilder = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Lego block falls from top
            [
                "....PPPP....",
                "....PPPP....",
                "............",
                "............",
                "............",
                "............",
                "............",
                "............",
                "............",
                "............",
                "TTTTTTTTTTTT",
                "............"
            ],
            // Frame 2: Lower
            [
                "............",
                "............",
                "............",
                "....PPPP....",
                "....PPPP....",
                "............",
                "............",
                "............",
                "............",
                "............",
                "TTTTTTTTTTTT",
                "............"
            ],
            // Frame 3: Lands
            [
                "............",
                "............",
                "............",
                "............",
                "............",
                "............",
                "............",
                "............",
                "....PPPP....",
                "S..SPPPPS..S",
                "TTTTTTTTTTTT",
                "............"
            ]
        ]
    )

    static let caution = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1
            [
                "............",
                "......P.....",
                ".....POP....",
                "....PO.OP...",
                "....PO.OP...",
                "...PO.Y.OP..",
                "...PO.Y.OP..",
                "..PO..Y..OP.",
                "..PO.....OP.",
                ".PO...Y...OP",
                "POOOOOOOOOOP",
                "............"
            ],
            // Frame 2: Triangles bounce/flash
            [
                "......P.....",
                ".....POP....",
                "....POTOP...",
                "....POTOP...",
                "...POTOP....",
                "...POTOP....",
                "..PO..OP....",
                "..PO.....OP.",
                ".PO...T...OP",
                "POOOOOOOOOOP",
                "............",
                "............"
            ]
        ]
    )

    static let successFlag = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Flag waving left
            [
                "......P.....",
                ".....PP.....",
                "....PPP.....",
                "....PP......",
                "....P.......",
                "....S.......",
                "....S.......",
                "....S.......",
                "....S.......",
                "....S.......",
                "..SSSSS.....",
                "............"
            ],
            // Frame 2: Flag waving right
            [
                "....PPP.....",
                ".....PP.....",
                "......P.....",
                "....PP......",
                "....P.......",
                "....S.......",
                "....S.......",
                "....S.......",
                "....S.......",
                "....S.......",
                "..SSSSS.....",
                "............"
            ]
        ]
    )

    static let failureCross = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Red cross
            [
                "............",
                "..R......R..",
                "...R....R...",
                "....R..R....",
                ".....RR.....",
                ".....RR.....",
                "....R..R....",
                "...R....R...",
                "..R......R..",
                "............",
                "............",
                "............"
            ],
            // Frame 2: Pulsing cross
            [
                "..T......T..",
                "...R....R...",
                "....R..R....",
                ".....RR.....",
                "....TRRT....",
                "....TRRT....",
                ".....RR.....",
                "....R..R....",
                "...R....R...",
                "..T......T..",
                "............",
                "............"
            ]
        ]
    )

    static let sleepZzz = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Sleep face
            [
                "............",
                "......SS....",
                ".....SS.....",
                "....SS......",
                "............",
                "............",
                "............",
                "....S.S.S...",
                "....S...S...",
                "...SSCCC...",
                "............",
                "............"
            ],
            // Frame 2: Z moving up
            [
                "....SS......",
                "...SS.......",
                "............",
                "........SS..",
                ".......SS...",
                "............",
                "............",
                "....S.S.S...",
                "....S...S...",
                "...SSCCC...",
                "............",
                "............"
            ],
            // Frame 3: Z further up
            [
                "........SS..",
                ".......SS...",
                "....SS......",
                "...SS.......",
                "............",
                "............",
                "............",
                "....S.S.S...",
                "....S...S...",
                "...SSCCC...",
                "............",
                "............"
            ]
        ]
    )

    // MARK: - Pac-Man/Retro Arcade Theme Sprites
    static let pacmanEating = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Pacman mouth open
            [
                "............",
                "....YYYY....",
                "..YYYYYYYY..",
                ".YYYY......",
                "YYYYY.......",
                "YYYYYYYY....",
                "YYYYYYYY....",
                "YYYYY.......",
                ".YYYY......",
                "..YYYYYYYY..",
                "....YYYY....",
                "............"
            ],
            // Frame 2: Pacman mouth eating a dot
            [
                "............",
                "....YYYY....",
                "..YYYYYYYY..",
                ".YYYYYYYYY..",
                "YYYYYYYYYY..",
                "YYYYYYYYYY.T", // eating a white pixel dot!
                "YYYYYYYYYY..",
                "YYYYYYYYYY..",
                ".YYYYYYYYY..",
                "..YYYYYYYY..",
                "....YYYY....",
                "............"
            ],
            // Frame 3: Pacman mouth closed
            [
                "............",
                "....YYYY....",
                "..YYYYYYYY..",
                ".YYYYYYYYY..",
                "YYYYYYYYYY..",
                "YYYYYYYYYY..",
                "YYYYYYYYYY..",
                "YYYYYYYYYY..",
                ".YYYYYYYYY..",
                "..YYYYYYYY..",
                "....YYYY....",
                "............"
            ]
        ]
    )

    static let ghostBlinky = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Red Ghost (Blinky) looking right/bouncing
            [
                "............",
                "....RRRR....",
                "..RRRRRRRR..",
                ".RRTT..TTRR.",
                ".RTBB..BBRT.",
                ".RTTT..TTTR.",
                ".RRRRRRRRRR.",
                ".RRRRRRRRRR.",
                ".RRRRRRRRRR.",
                ".R.R.RR.R.R.",
                "............",
                "............"
            ],
            // Frame 2: Red Ghost looking left/bouncing
            [
                "....RRRR....",
                "..RRRRRRRR..",
                ".RRT...TTRR.",
                ".RBB..BBRTT.",
                ".RTTT..TTTR.",
                ".RRRRRRRRRR.",
                ".RRRRRRRRRR.",
                ".RRRRRRRRRR.",
                ".RRRRRRRRRR.",
                ".RR.R.R.RR..",
                "............",
                "............"
            ]
        ]
    )

    static let pacmanCherry = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Cherry blinking
            [
                "......G.....",
                ".....G......",
                "....G.......",
                "..RRR..RRR..",
                ".RRRRR.RRRRR",
                ".RRRRR.RRRRR",
                "..RRR..RRR..",
                "............",
                "............",
                "............",
                "............",
                "............"
            ],
            // Frame 2: Glimmer cherry
            [
                "......G.....",
                ".....G......",
                "....G.......",
                "..RRR..RRR..",
                ".RTRRR.RTRRR", // light glint T
                ".RRRRR.RRRRR",
                "..RRR..RRR..",
                "............",
                "............",
                "............",
                "............",
                "............"
            ]
        ]
    )

    static let pacmanDying = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Shrunk wedges
            [
                "............",
                "....YYYY....",
                "..YY....YY..",
                ".YY......YY.",
                "Y..........Y",
                "............",
                "............",
                "Y..........Y",
                ".YY......YY.",
                "..YY....YY..",
                "....YYYY....",
                "............"
            ],
            // Frame 2: Disappeared wedge
            [
                "............",
                "............",
                "....YYYY....",
                "............",
                "............",
                "....SS......",
                "....SS......",
                "............",
                "............",
                "....YYYY....",
                "............",
                "............"
            ]
        ]
    )

    static let ghostBlue = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Scared blue ghost
            [
                "............",
                "....WWWW....",
                "..WWWWWWWW..",
                ".WWTWWWWTTW.",
                ".WTWWTWWTWW.",
                ".WWWWWWWWWW.",
                ".WWTWWWWTTW.",
                ".WWTWWWWTTW.",
                ".WWWWWWWWWW.",
                ".W.W.WW.W.W.",
                "............",
                "............"
            ],
            // Frame 2: Scared blue ghost white flash
            [
                "............",
                "....WWWW....",
                "..WWWWWWWW..",
                ".WWTWWWWTTW.",
                ".WTWWTWWTWW.",
                ".WWWWWWWWWW.",
                ".WWTWWWWTTW.",
                ".WWTWWWWTTW.",
                ".WWWWWWWWWW.",
                ".WTTWTTWTTW.",
                "............",
                "............"
            ]
        ]
    )

    // MARK: - Pokemon/Pocket Monsters Theme Sprites
    static let pokeballShaking = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Pokeball Centered
            [
                "............",
                "....RRRR....",
                "..RRRRRRRR..",
                ".RRRRRRRRRR.",
                ".RBBBBBBBBR.",
                ".RBBTTSSTBBR",
                ".RBBTTSSTBBR",
                ".RBBBBBBBBR.",
                ".SSTTTTTTSS.",
                "..TTTTTTTT..",
                "....TTTT....",
                "............"
            ],
            // Frame 2: Tilted Left
            [
                "......RRRR..",
                "....RRRRRRR.",
                "..RRRRRRRRR.",
                ".RBBBBBBBBR.",
                ".BBTTSSTBBR.",
                ".RBBTTSSTBB.",
                ".RBBBBBBBBR.",
                "..SSTTTTTTSS",
                "...TTTTTTTT.",
                ".....TTTT...",
                "............",
                "............"
            ],
            // Frame 3: Tilted Right
            [
                "..RRRR......",
                ".RRRRRRR....",
                ".RRRRRRRRR..",
                ".RBBBBBBBBR.",
                ".RBBTTSSTBB.",
                "..BBTTSSTBBR",
                ".RBBBBBBBBR.",
                "SSTTTTTTSS..",
                ".TTTTTTTT...",
                "..TTTT......",
                "............",
                "............"
            ]
        ]
    )

    static let pokeballAlert = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Pokéball with a warning glow
            [
                ".....YY.....", // flashing warning point
                "....RRRR....",
                "..RRRRRRRR..",
                ".RRRRRRRRRR.",
                ".RBBBBBBBBR.",
                ".RBBTTSSTBBR",
                ".RBBTTSSTBBR",
                ".RBBBBBBBBR.",
                ".SSTTTTTTSS.",
                "..TTTTTTTT..",
                "....TTTT....",
                "............"
            ],
            // Frame 2: Warning flash
            [
                ".....TT.....",
                "....RRRR....",
                "..RRRRRRRR..",
                ".RRRRRRRRRR.",
                ".RBBBBBBBBR.",
                ".RBBTTSSTBBR",
                ".RBBTTSSTBBR",
                ".RBBBBBBBBR.",
                ".SSTTTTTTSS.",
                "..TTTTTTTT..",
                "....TTTT....",
                "............"
            ]
        ]
    )

    static let pokeballCaught = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Caught Pokéball with stars
            [
                "....RRRR....",
                "..RRRRRRRR.T", // star T
                ".RRRBBBRRR..",
                "T.BBTTSSTBB.",
                ".RBBTTSSTBBR",
                "..RRRBBBRRR.",
                ".SSTTTTTTSS.",
                ".T.TTTTTTTT.",
                "....TTTT...T",
                "............",
                "............",
                "............"
            ],
            // Frame 2: Caught Pokéball loop
            [
                "T...RRRR...T",
                "..RRRRRRRR..",
                ".RTRBBBRRTR.",
                ".BBTTSSTBB.",
                ".RBBTTSSTBBR",
                "..RRRBBBRRR.",
                ".SSTTTTTTSS.",
                "..TTTTTTTT..",
                "....TTTT....",
                "............",
                "............",
                "............"
            ]
        ]
    )

    static let escapeSmoke = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Smoke expansion
            [
                "............",
                "....SSSS....",
                "..SSSSSSSS..",
                ".SSSSSSSSSS.",
                ".SSSSSSSSSS.",
                "..SSSSSSSS..",
                "....SSSS....",
                "............",
                "............",
                "............",
                "............",
                "............"
            ],
            // Frame 2: Particles disperse
            [
                "..S......S..",
                "...S....S...",
                "....S..S....",
                ".....SS.....",
                ".....SS.....",
                "....S..S....",
                "...S....S...",
                "..S......S..",
                "............",
                "............",
                "............",
                "............"
            ]
        ]
    )

    static let snorlaxSleeping = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Sleep snorlax face
            [
                "............",
                "...SSSSSS...",
                "..SSTTTTSS..",
                ".SSTTTTTTSS.",
                ".STTSTTSSTT.",
                ".STTSTTSSTT.",
                ".SSTTTTTTSS.",
                "..SSTTTTSS..",
                "...SSTTSS...",
                "....SSSS....",
                "............",
                "............"
            ],
            // Frame 2: Sleeping face with small Z
            [
                "........SS..",
                "...SSSSSS...",
                "..SSTTTTSS..",
                ".SSTTTTTTSS.",
                ".STTSTTSSTT.",
                ".STTSTTSSTT.",
                ".SSTTTTTTSS.",
                "..SSTTTTSS..",
                "...SSTTSS...",
                "....SSSS....",
                "............",
                "............"
            ]
        ]
    )

    // MARK: - Super Mario Theme Sprites
    static let marioRunning = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Mario Running (Left arm front)
            [
                "....RRRRR...",
                "...RYRYYY...",
                "...RYRYYYY..",
                "....RYRRR...",
                "...RBRBBR...",
                "..RRBRRBRR..",
                ".RRRBBBBB...",
                "....BBBBB...",
                "...SS...SS..",
                "...SS...SS..",
                "............",
                "............"
            ],
            // Frame 2: Mario Running (Right arm front)
            [
                "....RRRRR...",
                "...RYRYYY...",
                "...RYRYYYY..",
                "....RYRRR...",
                "..RRBRBBR...",
                "...RBRRBRR..",
                "....BBBBB...",
                "...RBBBBB...",
                "..SS.....SS.",
                "..SS.....SS.",
                "............",
                "............"
            ]
        ]
    )

    static let marioQuestion = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Gold Question mark block
            [
                ".BBBBBBBBBB.",
                "BYYYYYYYYYYB",
                "BY..YYYY..YB",
                "BY.Y....Y.YB",
                "BY......Y.YB",
                "BY....YY..YB",
                "BY....Y...YB",
                "BY........YB",
                "BY....Y...YB",
                "BYYYYYYYYYYB",
                ".BBBBBBBBBB.",
                "............"
            ],
            // Frame 2: Highlighting Question block
            [
                ".BBBBBBBBBB.",
                "BTTTTTTTTTTB",
                "BT..TTTT..TB",
                "BT.T....T.TB",
                "BT......T.TB",
                "BT....TT..TB",
                "BT....T...TB",
                "BT........TB",
                "BT....T...TB",
                "BTTTTTTTTTTB",
                ".BBBBBBBBBB.",
                "............"
            ]
        ]
    )

    static let marioMushroom = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Super Mushroom
            [
                "....GGGG....",
                "..GGGGGGGG..",
                ".GGTGGTGGGG.",
                "GGTGGTGGGGGG",
                "GGGGGGGGGGGG",
                ".BBTTTTTTBB.",
                "...TBT.TBT..",
                "...TTTTTTT..",
                "...TTTTTTT..",
                "....TTTT....",
                "............",
                "............"
            ],
            // Frame 2: Shimmering Mushroom
            [
                "....GGGG....",
                "..GGGGGGGG..",
                ".GGTGGTGGGG.",
                "GGTGGTGGGGGG",
                "GGGGGGGGGGGG",
                ".BBTTTTTTBB.",
                "...TBT.TBT..",
                "...TTTTTTT..",
                "...TTTTTTT..",
                "....TTTT....",
                "............",
                "............"
            ]
        ]
    )

    static let marioFireball = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Fireball / red shell
            [
                "....RRRR....",
                "..RRRRRRRR..",
                ".RRTTRRTTRR.",
                ".RRTTRRTTRR.",
                "RRRRRRRRRRRR",
                "RBBBBBBBBBBR",
                ".BBBBBBBBBB.",
                "............",
                "............",
                "............",
                "............",
                "............"
            ],
            // Frame 2: Rotating
            [
                "....RRRR....",
                "..RRRRRRRR..",
                ".RRRRRRRRRR.",
                ".RRRRRRRRRR.",
                "RRRRRRRRRRRR",
                "RBBBBBBBBBBR",
                ".BBBBBBBBBB.",
                "............",
                "............",
                "............",
                "............",
                "............"
            ]
        ]
    )

    static let marioCloud = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Lakitu Cloud Sleepy
            [
                "....TTTT....",
                "..TTTTTTTT..",
                ".TTTTTTTTTT.",
                ".TSS.TT.SST.",
                ".TTTTTTTTTT.",
                "..TTTTTTTT..",
                "...TTTTTT...",
                "............",
                "............",
                "............",
                "............",
                "............"
            ],
            // Frame 2: Lakitu Cloud with Z
            [
                "....TTTT....",
                "..TTTTTTTT.S",
                ".TTTTTTTTTT.",
                ".TSS.TT.SST.",
                ".TTTTTTTTTT.",
                "..TTTTTTTT..",
                "...TTTTTT...",
                "............",
                "............",
                "............",
                "............",
                "............"
            ]
        ]
    )

    // MARK: - Space Invaders Theme Sprites
    static let spaceInvader = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Invader legs straight down (matches user screenshot exactly)
            [
                "............",
                "...PPPPPP...",
                "..PPPPPPPP..",
                "..PPBPPBPP..",
                "..PPPPPPPP..",
                ".PPPPPPPPPP.",
                ".PPPPPPPPPP.",
                "..PPPPPPPP..",
                "..P.P..P.P..",
                "..P.P..P.P..",
                "............",
                "............"
            ],
            // Frame 2: Invader legs flare out
            [
                "............",
                "...PPPPPP...",
                "..PPPPPPPP..",
                "..PPBPPBPP..",
                "..PPPPPPPP..",
                ".PPPPPPPPPP.",
                ".PPPPPPPPPP.",
                "..PPPPPPPP..",
                ".P..P..P..P.",
                ".P..P..P..P.",
                "............",
                "............"
            ]
        ]
    )

    static let spaceUfo = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Saucer saucer (shifted down by 3 rows for alignment)
            [
                "............",
                "............",
                "............",
                "....PPPP....",
                "..PPPPPPPP..",
                ".PPYYYYYYPP.",
                "PPPPPPPPPPPP",
                ".P.P.P.P.P..",
                "............",
                "............",
                "............",
                "............"
            ],
            // Frame 2: Saucer flashing
            [
                "............",
                "............",
                "............",
                "....PPPP....",
                "..PPPPPPPP..",
                ".PPTTTTTTPP.",
                "PPPPPPPPPPPP",
                "..P.P.P.P.P.",
                "............",
                "............",
                "............",
                "............"
            ]
        ]
    )

    static let spaceCannon = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Cannon firing green ray upwards (shifted down by 2 rows for alignment)
            [
                "............",
                "............",
                ".....GG.....",
                ".....GG.....",
                "....GGGG....",
                "....GGGG....",
                "...GGGGGG...",
                "...GGGGGG...",
                "..GGGGGGGG..",
                "..GGGGGGGG..",
                "............",
                "............"
            ],
            // Frame 2: Green ray flashing
            [
                "............",
                "............",
                ".....TT.....",
                ".....TT.....",
                "....GGGG....",
                "....GGGG....",
                "...GGGGGG...",
                "...GGGGGG...",
                "..GGGGGGGG..",
                "..GGGGGGGG..",
                "............",
                "............"
            ]
        ]
    )

    static let spaceExplosion = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Explosion particles (shifted down by 2 rows for alignment)
            [
                "............",
                "............",
                "............",
                "..R...R...R.",
                "...R..R..R..",
                "....RRRR....",
                "....RRRR....",
                "...R..R..R..",
                "..R...R...R.",
                "............",
                "............",
                "............"
            ],
            // Frame 2: Wider dispersals
            [
                "............",
                "............",
                ".R.........R",
                "...R.....R..",
                "....R...R...",
                ".....R.R....",
                ".....R.R....",
                "....R...R...",
                "...R.....R..",
                ".R.........R",
                "............",
                "............"
            ]
        ]
    )

    static let spaceSlime = PixelSprite(
        width: 12,
        height: 12,
        frames: [
            // Frame 1: Slime monster floating (shifted down by 1 row for alignment)
            [
                "............",
                "............",
                "....SSSS....",
                "..SSSSSSSS..",
                ".SSTT..TTSS.",
                ".SSSSSSSSSS.",
                ".SSSSSSSSSS.",
                "..SSSSSSSS..",
                "...SS..SS...",
                "....SSSSS...",
                "............",
                "............"
            ],
            // Frame 2: Bouncing slightly
            [
                "............",
                "....SSSS....",
                "..SSSSSSSS..",
                ".SSTT..TTSS.",
                ".SSSSSSSSSS.",
                ".SSSSSSSSSS.",
                "..SSSSSSSS..",
                "...SS..SS...",
                "....SSSSS...",
                "............",
                "............",
                "............"
            ]
        ]
    )

    static func sprite(for state: SessionState, theme: AnimationTheme) -> PixelSprite {
        switch theme {
        case .lego:
            switch state {
            case .working: return robotDeveloper
            case .needsPermission, .needsInput: return caution
            case .done: return successFlag
            case .failed: return failureCross
            case .ended: return sleepZzz
            }
        case .pacman:
            switch state {
            case .working: return pacmanEating
            case .needsPermission, .needsInput: return ghostBlinky
            case .done: return pacmanCherry
            case .failed: return pacmanDying
            case .ended: return ghostBlue
            }
        case .pokemon:
            switch state {
            case .working: return pokeballShaking
            case .needsPermission, .needsInput: return pokeballAlert
            case .done: return pokeballCaught
            case .failed: return escapeSmoke
            case .ended: return snorlaxSleeping
            }
        case .mario:
            switch state {
            case .working: return marioRunning
            case .needsPermission, .needsInput: return marioQuestion
            case .done: return marioMushroom
            case .failed: return marioFireball
            case .ended: return marioCloud
            }
        case .space:
            switch state {
            case .working: return spaceInvader
            case .needsPermission, .needsInput: return spaceUfo
            case .done: return spaceCannon
            case .failed: return spaceExplosion
            case .ended: return spaceSlime
            }
        }
    }
}

struct PixelArtView: View {
    let sprite: PixelSprite
    let frameIndex: Int
    let size: CGFloat
    let stateAccent: Accent?

    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { context, cgSize in
            let cols = sprite.width
            let rows = sprite.height
            guard cols > 0, rows > 0 else { return }

            let cellW = cgSize.width / CGFloat(cols)
            let cellH = cgSize.height / CGFloat(rows)
            let frame = sprite.frames[frameIndex % sprite.frames.count]

            for r in 0..<rows {
                let rowStr = frame[r]
                let chars = Array(rowStr)
                for c in 0..<cols {
                    guard c < chars.count else { continue }
                    let char = chars[c]
                    if char == "." || char == " " { continue }

                    let color = colorForChar(char)
                    let rect = CGRect(x: CGFloat(c) * cellW, y: CGFloat(r) * cellH, width: cellW, height: cellH)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func colorForChar(_ char: Character) -> Color {
        switch char {
        case "W": return palette.working
        case "O": return palette.needsPermission
        case "Y": return palette.needsInputDot
        case "G": return palette.done
        case "R": return palette.failed
        case "T": return palette.textPrimary
        case "S": return palette.textSecondary
        case "B": return Color.black.opacity(0.8)
        case "C": return palette.innerBox
        case "P":
            if let stateAccent {
                return palette.accent(stateAccent)
            } else {
                return palette.working
            }
        default: return .clear
        }
    }
}

/// A periodic ticking container for driving retro-style frame transitions without global timers.
struct AnimatedPixelArtView: View {
    let state: SessionState
    let size: CGFloat
    let theme: AnimationTheme

    var body: some View {
        let sprite = PixelSprites.sprite(for: state, theme: theme)
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let frameIndex = Int(elapsed * 4) // 4 frames per second
            PixelArtView(sprite: sprite, frameIndex: frameIndex, size: size, stateAccent: state.surfaceAccent)
        }
        .frame(width: size, height: size)
    }
}

/// A retro/Lego-style pixel detail gauge for token composition in expanded cards.
struct PixelGaugeView: View {
    let tokens: TokenUsage
    @Environment(\.palette) private var palette

    var body: some View {
        let total = tokens.total
        guard total > 0 else { return AnyView(EmptyView()) }

        let segmentsCount = 20

        // Ensure accurate proportions for each bucket type without overloading the type checker
        let dTotal = Double(total)
        let dSegments = Double(segmentsCount)

        let readFraction = Double(tokens.cacheRead) / dTotal
        let readSegments = Int(round(readFraction * dSegments))

        let createFraction = Double(tokens.cacheCreation) / dTotal
        let creationSegments = Int(round(createFraction * dSegments))

        let outFraction = Double(tokens.output) / dTotal
        let outputSegments = Int(round(outFraction * dSegments))

        let inputSegments = max(0, segmentsCount - (readSegments + creationSegments + outputSegments))

        return AnyView(
            VStack(alignment: .leading, spacing: 5) {
                // Segmented retro health-style bar
                HStack(spacing: 2) {
                    ForEach(0..<segmentsCount, id: \.self) { index in
                        let color: Color = {
                            if index < readSegments {
                                return palette.working // Cache Read (Blue)
                            } else if index < readSegments + creationSegments {
                                return palette.needsPermission // Cache Create (Orange)
                            } else if index < readSegments + creationSegments + inputSegments {
                                return palette.textSecondary // Input (Gray)
                            } else {
                                return palette.done // Output (Green)
                            }
                        }()

                        // We make each segment look like a Lego stud / classic pixel grid block
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color)
                            .frame(width: 8, height: 11)
                            .shadow(color: color.opacity(0.3), radius: 1)
                    }
                }
                .padding(3)
                .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 3))

                // Detailed Legend (Dual rows to prevent text overlay / squishing on narrow widths)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 12) {
                        LegendItem(color: palette.working, text: "Read: \(Format.tokens(tokens.cacheRead))")
                        LegendItem(color: palette.needsPermission, text: "Create: \(Format.tokens(tokens.cacheCreation))")
                    }
                    HStack(spacing: 12) {
                        LegendItem(color: palette.textSecondary, text: "Input: \(Format.tokens(tokens.input))")
                        LegendItem(color: palette.done, text: "Output: \(Format.tokens(tokens.output))")
                    }
                }
                .font(.system(size: 9.5, weight: .medium))
            }
        )
    }
}

private struct LegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text).foregroundStyle(.secondary)
        }
    }
}
