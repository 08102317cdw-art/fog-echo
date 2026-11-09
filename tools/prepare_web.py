from pathlib import Path
import re


# 为 Godot 默认导出页面补上语言和准确的版本标识。
page = Path(__file__).resolve().parents[1] / "dist" / "index.html"
content = page.read_text(encoding="utf-8")
content = content.replace('<html lang="en">', '<html lang="zh-CN">')
content = re.sub(
    r"<title>.*?</title>",
    "<title>雾中回响 · v1.1 网页适配版</title>",
    content,
    count=1,
)
notice = """<aside id="version-note" style="position:fixed;top:12px;right:16px;z-index:100;pointer-events:none;padding:6px 10px;background:rgba(0,0,0,.65);color:#d6d0c6;font:13px/1.5 sans-serif;border:1px solid #555">
v1.1 网页适配版 · 仅供非商业学习交流
</aside>"""
if 'id="version-note"' not in content:
    content = content.replace("</body>", notice + "\n</body>")
page.write_text(content, encoding="utf-8")
print("已补全网页语言及 v1.1 版本说明")
