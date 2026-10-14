# explainer.html 상호작용 검사: 375px·다크·reduced-motion에서 키보드만으로 5종 동작 확인 + 1280px 스크롤 연동 단계 전환.
# 사용: python3 vault/patterns/explainer-verify/interact.py vault/patterns/explainer.html <캡처 폴더>
import sys, pathlib, json
from playwright.sync_api import sync_playwright
url = pathlib.Path(sys.argv[1]).resolve().as_uri()
out = pathlib.Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
res = {}
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={"width": 375, "height": 800}, reduced_motion="reduce", color_scheme="dark")
    errs = []; pg.on("console", lambda m: m.type == "error" and errs.append(m.text)); pg.on("pageerror", lambda e: errs.append(str(e)))
    pg.goto(url); pg.wait_for_timeout(500)
    res["overflow375"] = pg.evaluate("document.documentElement.scrollWidth > document.documentElement.clientWidth")
    res["reducedMotionTransition"] = pg.evaluate("getComputedStyle(document.querySelector('.ex-segs i')).transitionDuration")
    # 키보드만: Tab으로 모든 조작 요소 순회
    seen = []
    for _ in range(60):
        pg.keyboard.press("Tab")
        d = pg.evaluate("""(() => { const a = document.activeElement; return a ? (a.id || a.dataset.key || a.dataset.act || a.dataset.v || a.textContent.trim().slice(0,12)) + '|' + a.tagName : '' })()""")
        seen.append(d)
    res["tabStops"] = seen
    # 슬라이더: 포커스 후 → End
    pg.focus("#auto"); pg.keyboard.press("ArrowRight"); r1 = pg.get_attribute("#auto", "aria-valuetext")
    pg.keyboard.press("End"); r2 = pg.get_attribute("#auto", "aria-valuetext"); out_txt = pg.inner_text("#autoGuard")
    res["slider"] = [r1, r2, out_txt]
    # 시뮬레이터: 다음 단계 Enter 8번
    nxt = pg.locator('[data-act="next"]'); nxt.focus()
    for _ in range(8): pg.keyboard.press("Enter")
    res["stepper"] = {"state": pg.inner_text("#simState"), "logItems": pg.locator("#simLog li").count(),
        "nextDisabled": nxt.is_disabled(), "focused": pg.evaluate("document.activeElement.dataset.act"),
        "current": pg.evaluate("[...document.querySelectorAll('.ex-snode')].filter(g=>g.getAttribute('aria-current')==='step').map(g=>g.dataset.step)")}
    pg.screenshot(path=str(out/"stepper-done-375-dark.png"), clip=pg.locator(".ex-stepper").bounding_box())
    # 그래프: 노드 포커스 → 설명, Enter 고정, Esc 해제
    node = pg.locator('.ex-node[data-key="review"]'); node.focus()
    d1 = pg.inner_text("#lkDetail"); pg.keyboard.press("Enter"); pressed = node.get_attribute("aria-pressed")
    edgesOn = pg.locator(".ex-edge.is-on").count()
    pg.screenshot(path=str(out/"linked-review-375-dark.png"), clip=pg.locator("#linked").bounding_box())
    pg.keyboard.press("Escape"); pressed2 = node.get_attribute("aria-pressed")
    pg.locator(".ex-ref[data-key='router']").focus(); pg.keyboard.press("Enter"); refNode = pg.get_attribute('.ex-node[data-key="router"]', "aria-pressed")
    res["linked"] = {"focusDetail": d1[:40], "pressedAfterEnter": pressed, "edgesOn": edgesOn, "pressedAfterEsc": pressed2, "refPinsNode": refNode}
    res["scrolly375"] = {"clones": pg.locator(".ex-clone").count(), "live": pg.evaluate("document.querySelector('[data-scrolly]').classList.contains('is-live')")}
    # 데스크톱: 스크롤 연동 단계 전환
    pg.set_viewport_size({"width": 1280, "height": 800}); pg.wait_for_timeout(300)
    steps = []
    for i in range(4):
        pg.locator(f'.ex-step[data-step="{i}"]').scroll_into_view_if_needed()
        pg.evaluate(f"(() => {{ const r = document.querySelector('.ex-step[data-step=\"{i}\"]').getBoundingClientRect(); window.scrollBy(0, r.top + r.height/2 - innerHeight/2); }})()")
        pg.wait_for_timeout(250)
        steps.append(pg.get_attribute("[data-scrolly] > .ex-sticky .ex-flow", "aria-label")[:6])
    res["scrollyDesktop"] = {"live": pg.evaluate("document.querySelector('[data-scrolly]').classList.contains('is-live')"), "labels": steps}
    pg.screenshot(path=str(out/"scrolly-step3-1280-dark.png"))
    res["errors"] = errs
    b.close()
print(json.dumps(res, ensure_ascii=False, indent=1))
