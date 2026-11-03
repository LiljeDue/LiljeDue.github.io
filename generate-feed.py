import json, glob
from datetime import date, datetime
from xml.sax.saxutils import escape
from html import escape as html_escape

def xml_escape(text):
    return escape(text, {"'": "&apos;", '"': "&quot;"})

SITE_URL = "https://liljedue.dk"
FEED_TITLE = "Lilje Due's Blog"
FEED_AUTHOR = "Lilje Henrich Due"

entries = []
for path in glob.glob("content/blog/*/post.json"):
    slug = path.split("/")[2]
    with open(path) as f:
        meta = json.load(f)
    entries.append({
        "slug": slug,
        "title": meta["title"],
        "date": meta["date"],
        "author": meta.get("author", FEED_AUTHOR),
        "description": meta.get("description", ""),
    })

entries.sort(key=lambda e: e["date"], reverse=True)
updated = entries[0]["date"] + "T00:00:00Z" if entries else datetime.utcnow().isoformat() + "Z"

def atom_entry(e):
    url = f"{SITE_URL}/blog/{e['slug']}"
    return f"""  <entry>
    <title>{xml_escape(e['title'])}</title>
    <link href="{xml_escape(url)}"/>
    <id>{xml_escape(url)}</id>
    <updated>{e['date']}T00:00:00Z</updated>
    <author><name>{xml_escape(e['author'])}</name></author>
    <summary>{xml_escape(e['description'])}</summary>
  </entry>"""

atom = f"""<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>{FEED_TITLE}</title>
  <link href="{SITE_URL}/feed.xml" rel="self"/>
  <link href="{SITE_URL}/"/>
  <id>{SITE_URL}/</id>
  <updated>{updated}</updated>
  {''.join(atom_entry(e) for e in entries)}
</feed>"""

with open("content/feed.xml", "w") as f:
    f.write(atom)

print(f"feed.xml generated with {len(entries)} entries")

def post_item(e):
    d = date.fromisoformat(e["date"])
    return (f'                    <li><a href="/blog/{html_escape(e["slug"])}/">'
            f'{html_escape(e["title"])}</a> ({d.day} {d:%B %Y})</li>')

post_list = "<ul>\n" + "\n".join(map(post_item, entries)) + "\n                </ul>"
with open("templates/index.html") as f:
    template = f.read()
with open("index.html", "w") as f:
    f.write(template.replace("<!-- POSTS -->", post_list))