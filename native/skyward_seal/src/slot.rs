// ============================================================
// slot — authoritative slot-machine math for the native game
// ============================================================
// Every number the cabinet shows is computed HERE, never in the Dart
// AOT image: the reel strips, the paytable, the payline map, the
// scatter awards, the RNG that rolls a window and the evaluator that
// prices it. Dart only marshals a stake and an RNG seed across FFI and
// renders the JSON that comes back.
//
// Mark indices MUST stay identical to `lib/src/slot/marks.dart`:
//   0 cherry  1 orange  2 grape   3 bell    4 bar     5 ring
//   6 star    7 crown   8 diamond 9 seven  10 wild   11 scatter
//
// Tier codes match `Tier` in `lib/src/slot/engine.dart`:
//   0 none  1 big  2 mega  3 jackpot
// ============================================================

// ── Symbol indices ──────────────────────────────────────────
const CHERRY: u8 = 0;
const ORANGE: u8 = 1;
const GRAPE: u8 = 2;
const BELL: u8 = 3;
const BAR: u8 = 4;
const RING: u8 = 5;
const STAR: u8 = 6;
const CROWN: u8 = 7;
const DIAMOND: u8 = 8;
const SEVEN: u8 = 9;
const WILD: u8 = 10;
const SCATTER: u8 = 11;

const REELS: usize = 5;
const ROWS: usize = 3;
pub const LINE_COUNT: i64 = 20;

#[inline]
fn is_wild(m: u8) -> bool {
    m == WILD
}

#[inline]
fn is_scatter(m: u8) -> bool {
    m == SCATTER
}

// ── Paytable ─────────────────────────────────────────────────
// Line-bet multipliers for 3, 4 and 5 of a kind, left to right.
// Indexed by symbol; wild pays as its own symbol, scatter never pays
// on a line (it uses the scatter table below).
fn line_table(mark: u8) -> Option<[i64; 3]> {
    match mark {
        CHERRY => Some([10, 24, 60]),
        ORANGE => Some([10, 24, 60]),
        GRAPE => Some([12, 32, 80]),
        BELL => Some([12, 32, 90]),
        BAR => Some([15, 40, 110]),
        RING => Some([18, 50, 140]),
        STAR => Some([24, 70, 200]),
        CROWN => Some([30, 90, 250]),
        DIAMOND => Some([40, 120, 400]),
        SEVEN => Some([50, 160, 600]),
        WILD => Some([60, 220, 1000]),
        _ => None,
    }
}

fn line_pay(mark: u8, count: usize) -> i64 {
    if !(3..=5).contains(&count) {
        return 0;
    }
    match line_table(mark) {
        Some(t) => t[count - 3],
        None => 0,
    }
}

// Total-stake multipliers and free-spin awards, indexed by scatter count.
const SCATTER_STAKE_PAY: [i64; 6] = [0, 0, 0, 2, 10, 50];
const SCATTER_FREE_SPINS: [i64; 6] = [0, 0, 0, 8, 12, 20];

// Row index per reel, 0 at the top. Twenty fixed lines.
const PAYLINES: [[usize; REELS]; 20] = [
    [1, 1, 1, 1, 1],
    [0, 0, 0, 0, 0],
    [2, 2, 2, 2, 2],
    [0, 1, 2, 1, 0],
    [2, 1, 0, 1, 2],
    [0, 0, 1, 0, 0],
    [2, 2, 1, 2, 2],
    [1, 0, 0, 0, 1],
    [1, 2, 2, 2, 1],
    [0, 1, 1, 1, 0],
    [2, 1, 1, 1, 2],
    [1, 0, 1, 2, 1],
    [1, 2, 1, 0, 1],
    [0, 1, 0, 1, 0],
    [2, 1, 2, 1, 2],
    [1, 1, 0, 1, 1],
    [1, 1, 2, 1, 1],
    [0, 2, 0, 2, 0],
    [2, 0, 2, 0, 2],
    [0, 2, 2, 2, 0],
];

// ── Reel strips ──────────────────────────────────────────────
// Scatters sit only on reels 1, 3 and 5, with gaps so a single reel
// cannot show three of them. Built from a body plus evenly spaced
// inserts, identical to `_strip` in engine.dart.
fn build_strip(body: &[u8], inserts: &[u8]) -> Vec<u8> {
    let mut out: Vec<u8> = Vec::with_capacity(body.len() + inserts.len());
    let gap = body.len() as f64 / inserts.len() as f64;
    let mut next = gap / 2.0;
    let mut insert_at = 0usize;
    for (i, &b) in body.iter().enumerate() {
        if insert_at < inserts.len() && (i as f64) >= next {
            out.push(inserts[insert_at]);
            insert_at += 1;
            next += gap;
        }
        out.push(b);
    }
    while insert_at < inserts.len() {
        out.push(inserts[insert_at]);
        insert_at += 1;
    }
    out
}

fn reel_strips() -> [Vec<u8>; REELS] {
    [
        build_strip(
            &[
                CHERRY, ORANGE, GRAPE, BELL, BAR, CHERRY, STAR, RING, ORANGE, CROWN, CHERRY, GRAPE,
                DIAMOND, ORANGE, SEVEN, BELL, BAR, CHERRY, STAR, ORANGE, GRAPE, RING, CHERRY, CROWN,
                BAR, BELL, ORANGE, GRAPE, STAR, CHERRY,
            ],
            &[WILD, SCATTER, WILD, SCATTER, DIAMOND],
        ),
        build_strip(
            &[
                ORANGE, GRAPE, CHERRY, BELL, STAR, BAR, ORANGE, RING, GRAPE, CROWN, CHERRY, BELL,
                ORANGE, SEVEN, BAR, GRAPE, STAR, CHERRY, RING, ORANGE, DIAMOND, BELL, GRAPE, BAR,
                CHERRY, CROWN, ORANGE, STAR, GRAPE, BELL,
            ],
            &[WILD, SEVEN, WILD, DIAMOND],
        ),
        build_strip(
            &[
                GRAPE, CHERRY, ORANGE, STAR, BELL, BAR, GRAPE, CROWN, CHERRY, RING, ORANGE, SEVEN,
                GRAPE, BAR, STAR, CHERRY, DIAMOND, ORANGE, BELL, GRAPE, RING, CHERRY, BAR, CROWN,
                ORANGE, STAR, GRAPE, BELL, CHERRY, BAR,
            ],
            &[SCATTER, WILD, SCATTER, WILD, SCATTER],
        ),
        build_strip(
            &[
                BELL, ORANGE, CHERRY, GRAPE, RING, BAR, STAR, ORANGE, CROWN, CHERRY, GRAPE, SEVEN,
                BELL, BAR, ORANGE, DIAMOND, CHERRY, STAR, GRAPE, RING, ORANGE, BELL, BAR, CHERRY,
                CROWN, GRAPE, STAR, ORANGE, BELL, CHERRY,
            ],
            &[WILD, DIAMOND, WILD, SEVEN],
        ),
        build_strip(
            &[
                BAR, CHERRY, ORANGE, GRAPE, STAR, RING, BAR, BELL, CHERRY, CROWN, ORANGE, GRAPE,
                SEVEN, BAR, STAR, CHERRY, DIAMOND, ORANGE, RING, GRAPE, BELL, BAR, CHERRY, CROWN,
                STAR, ORANGE, GRAPE, BELL, CHERRY, BAR,
            ],
            &[SCATTER, WILD, SCATTER, WILD, DIAMOND],
        ),
    ]
}

// ── RNG ──────────────────────────────────────────────────────
// SplitMix64: one 64-bit seed from Dart, pulled once per reel. Rolling
// here (not in Dart) keeps the outcome distribution out of the AOT image.
struct SplitMix64 {
    state: u64,
}

impl SplitMix64 {
    fn new(seed: u64) -> Self {
        SplitMix64 { state: seed }
    }

    fn next_u64(&mut self) -> u64 {
        self.state = self.state.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.state;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    fn below(&mut self, bound: usize) -> usize {
        (self.next_u64() % bound as u64) as usize
    }
}

fn roll(seed: u64) -> [[u8; ROWS]; REELS] {
    let strips = reel_strips();
    let mut rng = SplitMix64::new(seed);
    let mut grid = [[0u8; ROWS]; REELS];
    for (reel, slot) in grid.iter_mut().enumerate() {
        let strip = &strips[reel];
        let start = rng.below(strip.len());
        for (row, cell) in slot.iter_mut().enumerate() {
            *cell = strip[(start + row) % strip.len()];
        }
    }
    grid
}

// ── Evaluation ───────────────────────────────────────────────
struct Run {
    pay: i64,
    length: usize,
}

// Best-paying run reading a payline left to right. Leading wilds can
// stand in for any symbol and also pay as a wild line in their own right.
fn best_run(cells: &[u8; REELS]) -> Run {
    let mut wilds = 0usize;
    for &m in cells.iter() {
        if !is_wild(m) {
            break;
        }
        wilds += 1;
    }
    let mut best_pay = if wilds >= 3 { line_pay(WILD, wilds) } else { 0 };
    let mut best_length = if wilds >= 3 { wilds } else { 0 };

    let mut target: Option<u8> = None;
    let mut count = 0usize;
    for &m in cells.iter() {
        if is_scatter(m) {
            break;
        }
        if is_wild(m) {
            count += 1;
            continue;
        }
        match target {
            None => {
                target = Some(m);
                count += 1;
            }
            Some(t) => {
                if m != t {
                    break;
                }
                count += 1;
            }
        }
    }
    if let Some(t) = target {
        if count >= 3 {
            let pay = line_pay(t, count);
            if pay > best_pay {
                best_pay = pay;
                best_length = count;
            }
        }
    }
    Run {
        pay: best_pay,
        length: best_length,
    }
}

pub struct Outcome {
    pub grid: [[u8; ROWS]; REELS],
    pub payout: i64,
    pub scatter_count: i64,
    pub free_spins: i64,
    pub tier: u8,
    /// (reel, row) cells that contributed to a win.
    pub hits: Vec<(usize, usize)>,
}

fn tier_for(payout: i64, stake: i64) -> u8 {
    if stake <= 0 || payout <= 0 {
        return 0;
    }
    let times = payout as f64 / stake as f64;
    if times >= 40.0 {
        3
    } else if times >= 25.0 {
        2
    } else if times >= 10.0 {
        1
    } else {
        0
    }
}

pub fn evaluate(grid: [[u8; ROWS]; REELS], stake: i64) -> Outcome {
    let line_bet = stake / LINE_COUNT;
    let mut hits: Vec<(usize, usize)> = Vec::new();
    let mut seen = [[false; ROWS]; REELS];
    let mut payout: i64 = 0;

    let push_hit = |reel: usize, row: usize, hits: &mut Vec<(usize, usize)>, seen: &mut [[bool; ROWS]; REELS]| {
        if !seen[reel][row] {
            seen[reel][row] = true;
            hits.push((reel, row));
        }
    };

    for rows in PAYLINES.iter() {
        let cells: [u8; REELS] = [
            grid[0][rows[0]],
            grid[1][rows[1]],
            grid[2][rows[2]],
            grid[3][rows[3]],
            grid[4][rows[4]],
        ];
        let run = best_run(&cells);
        if run.pay <= 0 || line_bet <= 0 {
            continue;
        }
        payout += run.pay * line_bet;
        for reel in 0..run.length {
            push_hit(reel, rows[reel], &mut hits, &mut seen);
        }
    }

    let mut scatters: Vec<(usize, usize)> = Vec::new();
    for reel in 0..REELS {
        for row in 0..ROWS {
            if is_scatter(grid[reel][row]) {
                scatters.push((reel, row));
            }
        }
    }
    let scatter_count = scatters.len().min(5);
    payout += stake * SCATTER_STAKE_PAY[scatter_count];
    if scatter_count >= 3 {
        for (reel, row) in scatters {
            push_hit(reel, row, &mut hits, &mut seen);
        }
    }

    Outcome {
        grid,
        payout,
        scatter_count: scatter_count as i64,
        free_spins: SCATTER_FREE_SPINS[scatter_count],
        tier: tier_for(payout, stake),
        hits,
    }
}

/// Roll a window from `seed` and price it.
pub fn spin(stake: i64, seed: u64) -> Outcome {
    evaluate(roll(seed), stake)
}

// ── JSON ─────────────────────────────────────────────────────
// Hand-built to match the crate's dependency-free style. All values are
// integers, so none need escaping.
pub fn outcome_json(o: &Outcome) -> String {
    let mut s = String::with_capacity(256);
    s.push_str("{\"grid\":[");
    for reel in 0..REELS {
        if reel > 0 {
            s.push(',');
        }
        s.push('[');
        for row in 0..ROWS {
            if row > 0 {
                s.push(',');
            }
            s.push_str(&o.grid[reel][row].to_string());
        }
        s.push(']');
    }
    s.push_str("],\"payout\":");
    s.push_str(&o.payout.to_string());
    s.push_str(",\"scatter\":");
    s.push_str(&o.scatter_count.to_string());
    s.push_str(",\"free\":");
    s.push_str(&o.free_spins.to_string());
    s.push_str(",\"tier\":");
    s.push_str(&o.tier.to_string());
    s.push_str(",\"hits\":[");
    for (i, (reel, row)) in o.hits.iter().enumerate() {
        if i > 0 {
            s.push(',');
        }
        s.push('[');
        s.push_str(&reel.to_string());
        s.push(',');
        s.push_str(&row.to_string());
        s.push(']');
    }
    s.push_str("]}");
    s
}

/// Parse a reel-major grid from 15 comma-separated indices
/// (`r0c0,r0c1,r0c2,r1c0,...`). `None` on any malformed field.
pub fn parse_grid(csv: &str) -> Option<[[u8; ROWS]; REELS]> {
    let mut it = csv.split(',');
    let mut grid = [[0u8; ROWS]; REELS];
    for reel in 0..REELS {
        for row in 0..ROWS {
            let raw = it.next()?.trim();
            let v: u8 = raw.parse().ok()?;
            if v > SCATTER {
                return None;
            }
            grid[reel][row] = v;
        }
    }
    if it.next().is_some() {
        return None;
    }
    Some(grid)
}

#[cfg(test)]
mod tests {
    use super::*;

    const OPENING: [[u8; ROWS]; REELS] = [
        [CROWN, ORANGE, STAR],
        [CHERRY, SEVEN, BELL],
        [DIAMOND, GRAPE, CROWN],
        [BELL, RING, ORANGE],
        [STAR, BAR, CHERRY],
    ];

    #[test]
    fn opening_window_pays_nothing() {
        let o = evaluate(OPENING, 100);
        assert_eq!(o.payout, 0);
        assert_eq!(o.free_spins, 0);
    }

    #[test]
    fn crown_line_is_a_big_win() {
        let grid: [[u8; ROWS]; REELS] = [
            [CROWN, CHERRY, STAR],
            [CROWN, ORANGE, RING],
            [CROWN, GRAPE, DIAMOND],
            [CROWN, BELL, SEVEN],
            [CROWN, BAR, CHERRY],
        ];
        let o = evaluate(grid, 100);
        assert_eq!(o.payout, 250 * (100 / 20));
        assert_eq!(o.tier, 1);
        assert_eq!(o.free_spins, 0);
    }

    #[test]
    fn five_sevens_are_a_mega_win() {
        let grid: [[u8; ROWS]; REELS] = [
            [SEVEN, CHERRY, STAR],
            [SEVEN, ORANGE, RING],
            [SEVEN, GRAPE, DIAMOND],
            [SEVEN, BELL, CROWN],
            [SEVEN, BAR, CHERRY],
        ];
        let o = evaluate(grid, 100);
        assert_eq!(o.payout, 600 * 5);
        assert_eq!(o.tier, 2);
    }

    #[test]
    fn five_wilds_are_a_jackpot() {
        let grid: [[u8; ROWS]; REELS] = [
            [WILD, CHERRY, STAR],
            [WILD, ORANGE, RING],
            [WILD, GRAPE, DIAMOND],
            [WILD, BELL, CROWN],
            [WILD, BAR, SEVEN],
        ];
        let o = evaluate(grid, 100);
        assert_eq!(o.tier, 3);
        assert!(o.payout >= 1000 * 5);
    }

    #[test]
    fn three_scatters_award_free_spins_and_no_line_prize() {
        let grid: [[u8; ROWS]; REELS] = [
            [SCATTER, CHERRY, ORANGE],
            [GRAPE, BELL, BAR],
            [STAR, SCATTER, RING],
            [CROWN, DIAMOND, SEVEN],
            [BAR, GRAPE, SCATTER],
        ];
        let o = evaluate(grid, 100);
        assert_eq!(o.scatter_count, 3);
        assert_eq!(o.free_spins, 8);
        assert_eq!(o.payout, 2 * 100);
        assert_eq!(o.tier, 0);
        assert_eq!(o.hits.len(), 3);
    }

    #[test]
    fn three_cherries_stay_a_small_win() {
        let grid: [[u8; ROWS]; REELS] = [
            [CHERRY, STAR, BAR],
            [CHERRY, RING, BELL],
            [CHERRY, CROWN, GRAPE],
            [ORANGE, DIAMOND, STAR],
            [GRAPE, SEVEN, RING],
        ];
        let o = evaluate(grid, 100);
        assert_eq!(o.payout, 10 * 5);
        assert_eq!(o.tier, 0);
        assert_eq!(o.hits.len(), 3);
    }

    #[test]
    fn a_dead_spin_pays_nothing() {
        let grid: [[u8; ROWS]; REELS] = [
            [CHERRY, STAR, BAR],
            [ORANGE, RING, GRAPE],
            [GRAPE, CROWN, ORANGE],
            [BELL, DIAMOND, CHERRY],
            [BAR, SEVEN, STAR],
        ];
        let o = evaluate(grid, 100);
        assert_eq!(o.payout, 0);
        assert_eq!(o.free_spins, 0);
        assert!(o.hits.is_empty());
    }

    #[test]
    fn wilds_extend_a_cherry_run() {
        let grid: [[u8; ROWS]; REELS] = [
            [CHERRY, ORANGE, STAR],
            [WILD, BELL, BAR],
            [CHERRY, GRAPE, RING],
            [ORANGE, SEVEN, CROWN],
            [BAR, DIAMOND, STAR],
        ];
        let o = evaluate(grid, 100);
        assert_eq!(o.payout, 10 * 5);
        assert!(o.hits.contains(&(0, 0)));
        assert!(o.hits.contains(&(1, 0)));
        assert!(o.hits.contains(&(2, 0)));
    }

    #[test]
    fn return_stays_inside_a_social_casino_range() {
        let mut wagered: i64 = 0;
        let mut returned: i64 = 0;
        let mut seed: u64 = 7;
        let mut next_seed = || {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            seed
        };
        for _ in 0..8000 {
            let stake = 20;
            wagered += stake;
            let o = spin(stake, next_seed());
            returned += o.payout;
            let mut free = o.free_spins;
            let mut guard = 0;
            while free > 0 && guard < 80 {
                guard += 1;
                free -= 1;
                let extra = spin(stake, next_seed());
                returned += extra.payout * 2;
                free += extra.free_spins;
            }
        }
        let rtp = returned as f64 / wagered as f64;
        assert!((0.82..=1.08).contains(&rtp), "rtp={rtp}");
    }

    #[test]
    fn grid_round_trips_through_csv() {
        let o = spin(100, 1);
        let csv = (0..REELS)
            .flat_map(|r| (0..ROWS).map(move |c| (r, c)))
            .map(|(r, c)| o.grid[r][c].to_string())
            .collect::<Vec<_>>()
            .join(",");
        let parsed = parse_grid(&csv).unwrap();
        assert_eq!(parsed, o.grid);
        assert!(parse_grid("1,2,3").is_none());
        assert!(parse_grid("0,0,0,0,0,0,0,0,0,0,0,0,0,0,99").is_none());
    }
}
