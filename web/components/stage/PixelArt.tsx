"use client";
import React, { useEffect, useState } from "react";
import type { SessionState, AnimationThemeId } from "@/lib/types";

interface PixelSprite {
  width: number;
  height: number;
  frames: string[][];
}

const PixelSprites: Record<string, PixelSprite> = {
  // LEGO BUILDER
  robotDeveloper: {
    width: 12, height: 12,
    frames: [
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
  },
  caution: {
    width: 12, height: 12,
    frames: [
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
  },
  successFlag: {
    width: 12, height: 12,
    frames: [
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
  },
  failureCross: {
    width: 12, height: 12,
    frames: [
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
  },
  sleepZzz: {
    width: 12, height: 12,
    frames: [
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
  },

  // PACMAN
  pacmanEating: {
    width: 12, height: 12,
    frames: [
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
      [
        "............",
        "....YYYY....",
        "..YYYYYYYY..",
        ".YYYYYYYYY..",
        "YYYYYYYYYY..",
        "YYYYYYYYYY.T",
        "YYYYYYYYYY..",
        "YYYYYYYYYY..",
        ".YYYYYYYYY..",
        "..YYYYYYYY..",
        "....YYYY....",
        "............"
      ],
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
  },
  ghostBlinky: {
    width: 12, height: 12,
    frames: [
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
  },
  pacmanCherry: {
    width: 12, height: 12,
    frames: [
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
      [
        "......G.....",
        ".....G......",
        "....G.......",
        "..RRR..RRR..",
        ".RTRRR.RTRRR",
        ".RRRRR.RRRRR",
        "..RRR..RRR..",
        "............",
        "............",
        "............",
        "............",
        "............"
      ]
    ]
  },
  pacmanDying: {
    width: 12, height: 12,
    frames: [
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
  },
  ghostBlue: {
    width: 12, height: 12,
    frames: [
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
  },

  // POKEMON
  pokeballShaking: {
    width: 12, height: 12,
    frames: [
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
  },
  pokeballAlert: {
    width: 12, height: 12,
    frames: [
      [
        ".....YY.....",
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
  },
  pokeballCaught: {
    width: 12, height: 12,
    frames: [
      [
        "....RRRR....",
        "..RRRRRRRR.T",
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
  },
  escapeSmoke: {
    width: 12, height: 12,
    frames: [
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
  },
  snorlaxSleeping: {
    width: 12, height: 12,
    frames: [
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
  },

  // MARIO
  marioRunning: {
    width: 12, height: 12,
    frames: [
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
  },
  marioQuestion: {
    width: 12, height: 12,
    frames: [
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
  },
  marioMushroom: {
    width: 12, height: 12,
    frames: [
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
  },
  marioFireball: {
    width: 12, height: 12,
    frames: [
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
  },
  marioCloud: {
    width: 12, height: 12,
    frames: [
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
  },

  // SPACE INVADERS
  spaceInvader: {
    width: 12, height: 12,
    frames: [
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
  },
  spaceUfo: {
    width: 12, height: 12,
    frames: [
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
  },
  spaceLaser: {
    width: 12, height: 12,
    frames: [
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
  },
  spaceExplosion: {
    width: 12, height: 12,
    frames: [
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
  },
  spaceSlime: {
    width: 12, height: 12,
    frames: [
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
        "............",
        "............"
      ]
    ]
  }
};

function getSpriteForState(state: SessionState, theme: AnimationThemeId): PixelSprite {
  switch (theme) {
    case "lego":
      switch (state) {
        case "working": return PixelSprites.robotDeveloper;
        case "needsPermission": case "needsInput": return PixelSprites.caution;
        case "done": return PixelSprites.successFlag;
        case "failed": return PixelSprites.failureCross;
        default: return PixelSprites.sleepZzz;
      }
    case "pacman":
      switch (state) {
        case "working": return PixelSprites.pacmanEating;
        case "needsPermission": case "needsInput": return PixelSprites.ghostBlinky;
        case "done": return PixelSprites.pacmanCherry;
        case "failed": return PixelSprites.pacmanDying;
        default: return PixelSprites.ghostBlue;
      }
    case "pokemon":
      switch (state) {
        case "working": return PixelSprites.pokeballShaking;
        case "needsPermission": case "needsInput": return PixelSprites.pokeballAlert;
        case "done": return PixelSprites.pokeballCaught;
        case "failed": return PixelSprites.escapeSmoke;
        default: return PixelSprites.snorlaxSleeping;
      }
    case "mario":
      switch (state) {
        case "working": return PixelSprites.marioRunning;
        case "needsPermission": case "needsInput": return PixelSprites.marioQuestion;
        case "done": return PixelSprites.marioMushroom;
        case "failed": return PixelSprites.marioFireball;
        default: return PixelSprites.marioCloud;
      }
    case "space":
      switch (state) {
        case "working": return PixelSprites.spaceInvader;
        case "needsPermission": case "needsInput": return PixelSprites.spaceUfo;
        case "done": return PixelSprites.spaceLaser;
        case "failed": return PixelSprites.spaceExplosion;
        default: return PixelSprites.spaceSlime;
      }
  }
}

interface PixelArtProps {
  sprite: PixelSprite;
  frameIndex: number;
  size: number;
  state: SessionState;
}

export function PixelArt({ sprite, frameIndex, size, state }: PixelArtProps) {
  const cols = sprite.width;
  const rows = sprite.height;
  const frame = sprite.frames[frameIndex % sprite.frames.length];

  const stateColor = {
    working: "var(--st-working)",
    needsPermission: "var(--st-perm)",
    needsInput: "var(--needs-input-dot)",
    done: "var(--st-done)",
    failed: "var(--st-failed)",
  }[state] || "var(--text-secondary)";

  // Flatten the 12x12 grid into a single flat array to prevent hydration / nested key issues
  const cells = frame.flatMap((row, rIdx) =>
    Array.from(row).map((char, cIdx) => ({
      char,
      key: `${rIdx}-${cIdx}`,
    }))
  );

  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: `repeat(${cols}, 1fr)`,
        gridTemplateRows: `repeat(${rows}, 1fr)`,
        width: size,
        height: size,
      }}
    >
      {cells.map(({ char, key }) => {
        let color = "transparent";
        if (char === "W") color = "var(--st-working)";
        else if (char === "O") color = "var(--st-perm)";
        else if (char === "Y") color = "var(--needs-input-dot)";
        else if (char === "G") color = "var(--st-done)";
        else if (char === "R") color = "var(--st-failed)";
        else if (char === "T") color = "var(--text-primary)";
        else if (char === "S") color = "var(--text-secondary)";
        else if (char === "B") color = "rgba(0,0,0,0.85)";
        else if (char === "C") color = "var(--inner-box)";
        else if (char === "P") color = stateColor;

        return (
          <div
            key={key}
            style={{
              backgroundColor: color,
              width: "100%",
              height: "100%",
            }}
          />
        );
      })}
    </div>
  );
}

interface AnimatedPixelArtProps {
  state: SessionState;
  size: number;
  theme: AnimationThemeId;
}

export function AnimatedPixelArt({ state, size, theme }: AnimatedPixelArtProps) {
  const [frameIndex, setFrameIndex] = useState(0);
  const sprite = getSpriteForState(state, theme);

  useEffect(() => {
    const timer = setInterval(() => {
      setFrameIndex((prev) => prev + 1);
    }, 250); // 4 FPS arpeggio
    return () => clearInterval(timer);
  }, [sprite]);

  return <PixelArt sprite={sprite} frameIndex={frameIndex} size={size} state={state} />;
}
