"""Plays a full 3-player game of Saltmarsh Isles in Chrome, records a video, and checks rule invariants after every action.

Buttons (Roll, Build, Buy, Play, Trade, Discard, Steal, End turn) are clicked for real.
Board taps (corners, edges, tiles) call the same handler the SVG element's onclick calls.
"""
import asyncio, json, sys
from playwright.async_api import async_playwright

GAME = 'file:///home/claude/saltmarsh.html'
OUT = sys.argv[1]
PAUSE = 70  # ms between actions, so the video is watchable

BOT_JS = r"""
window.bot = {
  pips: n => n ? 6 - Math.abs(7 - n) : 0,
  spotScore(vi, pi) {
    const v = G.verts[vi], have = new Set();
    G.verts.forEach(x => { if (x.owner === pi) x.tiles.forEach(t => have.add(G.tiles[t].res)) });
    let s = 0; v.tiles.forEach(t => { const T = G.tiles[t]; if (T.res !== 'desert') s += this.pips(T.num) + (have.has(T.res) ? 0 : 1.5) });
    if (G.ports.some(p => p.a === vi || p.b === vi)) s += 1;
    return s;
  },
  best(arr, f) { let b = null, bs = -1e9; arr.forEach(x => { const s = f(x); if (s > bs) { bs = s; b = x } }); return b },
  setup() {
    if (G.setupSub === 'settle') {
      const c = G.verts.map((_, i) => i).filter(i => canSettle(i, G.cur, true));
      return { kind: 'vert', i: this.best(c, i => this.spotScore(i, G.cur)) };
    }
    const c = G.edges.map((_, i) => i).filter(i => canRoad(i, G.cur));
    return { kind: 'edge', i: this.best(c, i => { const e = G.edges[i], far = e.a === G.lastSettle ? e.b : e.a; return Math.max(...G.verts[far].adj.map(a => canSettle(a, G.cur, true) ? this.spotScore(a, G.cur) : 0)) }) };
  },
  discardPicks() {
    const d = G.discards[0], h = { ...G.players[d.pi].hand }, picks = [];
    for (let k = 0; k < d.need; k++) { const r = this.best(RES.filter(r => h[r] > 0), r => h[r]); h[r]--; picks.push(r) }
    return picks;
  },
  robberTile() {
    const me = G.cur, lead = this.best(G.players.map((_, i) => i).filter(i => i !== me), i => vp(i) * 10 + total(G.players[i]));
    const c = G.tiles.map((_, i) => i).filter(i => i !== G.robber && !G.tiles[i].v.some(v => G.verts[v].owner === me));
    const pool = c.length ? c : G.tiles.map((_, i) => i).filter(i => i !== G.robber);
    return this.best(pool, i => { const t = G.tiles[i]; return t.v.reduce((s, v) => s + (G.verts[v].owner === lead ? (G.verts[v].city ? 2 : 1) * this.pips(t.num) * 2 : G.verts[v].owner != null ? this.pips(t.num) : 0), 0) });
  },
  // Next main-phase action for the current player, or {kind:'end'}.
  next() {
    const p = P(), me = G.cur;
    const play = p.dev.findIndex(c => canPlay(c) && c.type !== 'knight');
    if (play >= 0) { const c = p.dev[play];
      if (c.type === 'plenty') { const need = ['ore', 'grain', 'ore', 'wool'].filter(r => p.hand[r] < 2); devSel.plenty1 = need[0] || 'ore'; devSel.plenty2 = need[1] || 'grain' }
      if (c.type === 'market') devSel.market = this.best(RES, r => G.players.reduce((s, q, i) => s + (i === me ? 0 : q.hand[r]), 0));
      return { kind: 'play', idx: play } }
    const kn = p.dev.findIndex(c => canPlay(c) && c.type === 'knight');
    if (kn >= 0 && (G.players.some((q, i) => i !== me && q.knights >= p.knights) || p.knights < 3)) return { kind: 'play', idx: kn };
    const cityAt = G.verts.map((_, i) => i).filter(i => G.verts[i].owner === me && !G.verts[i].city);
    if (afford(p, COST.city) && cityAt.length) return { kind: 'build', btn: '#bCity', vert: this.best(cityAt, i => this.spotScore(i, me)) };
    const setAt = G.verts.map((_, i) => i).filter(i => canSettle(i, me, false));
    if (afford(p, COST.settle) && setAt.length) return { kind: 'build', btn: '#bSettle', vert: this.best(setAt, i => this.spotScore(i, me)) };
    if (afford(p, COST.road) && !setAt.length && G.edges.filter(e => e.owner === me).length < 15) {
      const roads = G.edges.map((_, i) => i).filter(i => canRoad(i, me));
      if (roads.length) return { kind: 'build', btn: '#bRoad', edge: this.best(roads, i => { const e = G.edges[i];
        return Math.max(...[e.a, e.b].map(v => G.verts[v].owner == null && !G.verts[v].adj.some(a => G.verts[a].owner != null) ? this.spotScore(v, me) : 0)) + Math.random() }) };
    }
    if (afford(p, COST_DEV) && G.deck.length && !(cityAt.length && p.hand.ore >= 2)) return { kind: 'buy' };
    // Trade: give the most plentiful resource for whatever a city or settlement is short of.
    const target = cityAt.length ? COST.city : COST.settle, short = RES.find(r => (target[r] || 0) > p.hand[r]);
    if (short) {
      const give = this.best(RES.filter(r => r !== short && p.hand[r] >= rate(me, r) + (target[r] || 0)), r => p.hand[r] - rate(me, r));
      if (give) { const n = rate(me, give);
        if (n === 4) return { kind: 'bank', give, get: short };
        const h = myHarbours(me).find(h => h.pt.ratio === n && (h.pt.kind === 'any' || h.pt.kind === give));
        return { kind: 'harbour', idx: h.i, give, get: short } }
    }
    return { kind: 'end' };
  },
  // Rule invariants, checked after every action. Returns a list of problems.
  check() {
    const bad = [];
    G.players.forEach((p, i) => { RES.forEach(r => { if (p.hand[r] < 0) bad.push(p.name + ' has ' + p.hand[r] + ' ' + r) }) });
    G.verts.forEach((v, i) => { if (v.owner != null && v.adj.some(a => G.verts[a].owner != null)) bad.push('distance rule broken at corner ' + i) });
    G.edges.forEach((e, i) => { if (e.owner == null) return; const ok = [e.a, e.b].some(v => G.verts[v].owner === e.owner || edgesAt(v).some(x => x !== e && x.owner === e.owner)); if (!ok) bad.push('road ' + i + ' disconnected') });
    G.verts.forEach((v, i) => { if (v.owner != null && G.phase !== 'setup' && !edgesAt(i).some(e => e.owner === v.owner)) bad.push('settlement ' + i + ' has no road') });
    const len = G.players.map((_, i) => roadLength(i));
    if (G.roadHolder != null && len[G.roadHolder] < 5) bad.push('longest road holder under 5');
    if (G.roadHolder != null && len.some(l => l > len[G.roadHolder])) bad.push('longest road holder is not longest');
    if (G.armyHolder != null && (G.players[G.armyHolder].knights < 3 || G.players.some(q => q.knights > G.players[G.armyHolder].knights))) bad.push('largest army holder wrong');
    const cards = G.deck.length + G.players.reduce((s, p) => s + p.dev.length, 0);
    if (cards > 25) bad.push('more than 25 dev cards');
    return bad;
  },
  summary() { return G.players.map((p, i) => ({ name: p.name, public: vp(i), hidden: vpCards(i), settlements: G.verts.filter(v => v.owner === i && !v.city).length, cities: G.verts.filter(v => v.owner === i && v.city).length, roads: G.edges.filter(e => e.owner === i).length, road: roadLength(i), knights: p.knights, cards: total(p) })) }
};
"""

async def main():
    stats = {'actions': 0, 'rolls': 0, 'sevens': 0, 'discards': 0, 'steals': 0, 'trades_bank': 0, 'trades_harbour': 0,
             'dev_bought': 0, 'dev_played': {}, 'built': {'road': 0, 'settlement': 0, 'city': 0}, 'problems': [], 'errors': []}
    async with async_playwright() as pw:
        b = await pw.chromium.launch(executable_path='/usr/bin/google-chrome')
        ctx = await b.new_context(viewport={'width': 1200, 'height': 860}, record_video_dir=OUT, record_video_size={'width': 1200, 'height': 860})
        pg = await ctx.new_page()
        pg.on('pageerror', lambda e: stats['errors'].append(str(e)))
        await pg.goto(GAME); await pg.wait_for_timeout(600)
        await pg.evaluate(BOT_JS)

        async def step():
            stats['actions'] += 1
            await pg.wait_for_timeout(PAUSE)
            for prob in await pg.evaluate('bot.check()'):
                if prob not in stats['problems']: stats['problems'].append(prob)

        async def handle_interrupts():
            # discards, robber, steal: whatever the game is waiting on
            while True:
                st = await pg.evaluate('({d:G.discards.length,r:G.robberPending,v:!!G.victims})')
                if st['d']:
                    for r in await pg.evaluate('bot.discardPicks()'):
                        await pg.click(f'#discard [data-r="{r}"][data-d="1"]')
                    await pg.click('#dOk'); stats['discards'] += 1; await step()
                elif st['r']:
                    await pg.evaluate('moveRobber(bot.robberTile())'); await step()
                elif st['v']:
                    await pg.click('#steal button >> nth=0'); stats['steals'] += 1; await step()
                else:
                    return

        # Setup
        while await pg.evaluate("G.phase==='setup'"):
            a = await pg.evaluate('bot.setup()')
            await pg.evaluate(f"{'clickVert' if a['kind']=='vert' else 'clickEdge'}({a['i']})"); await step()

        turns = 0
        while await pg.evaluate("G.phase==='play'") and turns < 600:
            turns += 1
            # Knight before rolling if the robber is on one of my tiles
            kn = await pg.evaluate("P().dev.findIndex(c=>c.type==='knight'&&canPlay(c)&&G.tiles[G.robber].v.some(v=>G.verts[v].owner===G.cur))")
            if kn >= 0:
                await pg.click(f'#devs button[data-p="{kn}"]'); stats['dev_played']['knight'] = stats['dev_played'].get('knight', 0) + 1
                await step(); await handle_interrupts()
            await pg.click('#roll'); stats['rolls'] += 1
            if sum(await pg.evaluate('G.dice')) == 7: stats['sevens'] += 1
            await step(); await handle_interrupts()
            for _ in range(30):
                if await pg.evaluate("G.phase!=='play'"): break
                a = await pg.evaluate('bot.next()')
                if a['kind'] == 'end': break
                if a['kind'] == 'build':
                    await pg.click(a['btn'])
                    if 'vert' in a: await pg.evaluate(f"clickVert({a['vert']})")
                    else: await pg.evaluate(f"clickEdge({a['edge']})")
                    stats['built'][{'#bCity': 'city', '#bSettle': 'settlement', '#bRoad': 'road'}[a['btn']]] += 1
                elif a['kind'] == 'buy':
                    await pg.click('#bDev'); stats['dev_bought'] += 1
                elif a['kind'] == 'play':
                    t = await pg.evaluate(f"P().dev[{a['idx']}].type")
                    await pg.click(f'#devs button[data-p="{a["idx"]}"]'); stats['dev_played'][t] = stats['dev_played'].get(t, 0) + 1
                    await step(); await handle_interrupts()
                    while await pg.evaluate("G.mode==='free'"):
                        e = await pg.evaluate("bot.best(G.edges.map((_,i)=>i).filter(i=>canRoad(i,G.cur)),()=>Math.random())")
                        await pg.evaluate(f'clickEdge({e})'); stats['built']['road'] += 1; await step()
                elif a['kind'] == 'bank':
                    await pg.select_option('#tGive', a['give']); await pg.select_option('#tGet', a['get'])
                    await pg.click('#bTrade'); stats['trades_bank'] += 1
                elif a['kind'] == 'harbour':
                    await pg.evaluate(f"hsel[{a['idx']}]={{give:'{a['give']}',get:'{a['get']}'}};render()")
                    await pg.click(f'#harbours button[data-t="{a["idx"]}"]'); stats['trades_harbour'] += 1
                await step()
            if await pg.evaluate("G.phase!=='play'"): break
            await pg.click('#bEnd'); await step()

        await pg.wait_for_timeout(3500)  # let the confetti play on camera
        stats['turns'] = turns
        stats['winner'] = await pg.evaluate("G.winner!=null?G.players[G.winner].name:null")
        stats['final'] = await pg.evaluate('bot.summary()')
        stats['log_tail'] = await pg.evaluate('G.log.slice(0,6)')
        await pg.screenshot(path=OUT + '/final.png')
        await ctx.close(); await b.close()
    print(json.dumps(stats, indent=1))

asyncio.run(main())
