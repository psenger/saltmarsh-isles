import asyncio
from playwright.async_api import async_playwright
SETUP="""()=>{while(G.phase==='setup'){const v=G.verts.findIndex((_,i)=>canSettle(i,G.cur,true));clickVert(v);const e=G.edges.findIndex((_,i)=>canRoad(i,G.cur));clickEdge(e)}}"""
async def shot(pg,name):
    await pg.wait_for_timeout(250);await pg.screenshot(path=f'steps/{name}.png')
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(executable_path='/usr/bin/google-chrome')
        pg=await b.new_page(viewport={'width':1200,'height':900})
        await pg.emulate_media(reduced_motion='reduce')  # freeze pulses so stills are clean
        await pg.goto('file:///home/claude/saltmarsh.html');await pg.wait_for_timeout(300)
        # ---- Flow A: rolling a 7 ----
        await pg.evaluate(SETUP)
        await pg.evaluate("""()=>{G.players[0].hand={timber:1,clay:1,wool:1,grain:1,ore:0};G.players[1].hand={timber:3,clay:2,wool:2,grain:1,ore:1};G.players[2].hand={timber:0,clay:4,wool:2,grain:2,ore:2};render()}""")
        await shot(pg,'A0-before')
        await pg.evaluate("()=>{Math._r=Math.random;let k=0;Math.random=()=>[.5,.45][k++]??Math._r()}")
        await pg.click('#roll');await pg.evaluate("()=>{Math.random=Math._r}")
        await shot(pg,'A1-rolled-cobalt-discards')
        for r,n in [('timber',3),('clay',1)]:
            for _ in range(n): await pg.click(f'#discard [data-r="{r}"][data-d="1"]')
        await shot(pg,'A2-cobalt-picked')
        await pg.click('#dOk');await shot(pg,'A3-amber-discards')
        for r,n in [('clay',3),('ore',2)]:
            for _ in range(n): await pg.click(f'#discard [data-r="{r}"][data-d="1"]')
        await pg.click('#dOk');await shot(pg,'A4-move-robber')
        ti=await pg.evaluate("G.tiles.findIndex((t,i)=>i!==G.robber&&t.v.some(v=>G.verts[v].owner===1))")
        await pg.evaluate(f"moveRobber({ti})");await shot(pg,'A5-choose-victim')
        await pg.click('#steal button >> nth=0');await shot(pg,'A6-after-steal')
        # ---- Flow B: Knight before rolling ----
        await pg.click('#bEnd');await pg.evaluate('endTurn();endTurn()')  # skip Cobalt and Amber's turns, back to Crimson
        await pg.evaluate("()=>{G.players[0].dev=[{type:'knight',turn:0},{type:'plenty',turn:0}];render()}")
        await shot(pg,'B0-knight-ready')
        await pg.click('#devs button[data-p="0"]');await shot(pg,'B1-knight-played')
        ti=await pg.evaluate("G.tiles.findIndex((t,i)=>i!==G.robber&&t.v.some(v=>G.verts[v].owner===2))")
        await pg.evaluate(f"moveRobber({ti})");await shot(pg,'B2-choose-victim')
        await pg.click('#steal button >> nth=0');await shot(pg,'B3-after-steal-roll-next')
        await b.close()
asyncio.run(main())
