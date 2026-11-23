#!/usr/bin/env python3
"""Build an English visual user guide from native renders of the actual SwiftUI view."""
from pathlib import Path
from io import BytesIO
import json
from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, Color, white
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.utils import ImageReader
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph

ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'output/pdf';OUT.mkdir(parents=True,exist_ok=True)
SCREENS=ROOT/'docs/guide/screens'
pdfmetrics.registerFont(TTFont('Arial','/System/Library/Fonts/Supplemental/Arial.ttf'))
pdfmetrics.registerFont(TTFont('ArialBold','/System/Library/Fonts/Supplemental/Arial Bold.ttf'))
W,H=841.89,595.28
CREAM=HexColor('#F4F0EB');INK=HexColor('#1C2024');MUTED=HexColor('#666B70');ORANGE=HexColor('#D6532B');LINE=HexColor('#DAD4CC')
PDF=OUT/'TileForge_Visual_Guide.pdf'
c=canvas.Canvas(str(PDF),pagesize=(W,H),pageCompression=1)
c.setTitle('TileForge - Visual User Guide');c.setAuthor('TileForge');c.setSubject('Nine steps from sign-in to image export')

def text(x,top,value,size=12,color=INK,bold=False):
 c.setFillColor(color);c.setFont('ArialBold' if bold else 'Arial',size);c.drawString(x,H-top-size*.82,value)
def para(x,top,value,width=250,size=12.5,color=INK,bold=False):
 style=ParagraphStyle('p',fontName='ArialBold' if bold else 'Arial',fontSize=size,leading=size*1.43,textColor=color,spaceAfter=0)
 p=Paragraph(value,style);_,h=p.wrap(width,1000);p.drawOn(c,x,H-top-h);return h

def box(x,top,w,h,fill=white,stroke=None,r=10):
 c.setFillColor(fill)
 if stroke:c.setStrokeColor(stroke)
 c.roundRect(x,H-top-h,w,h,r,fill=1,stroke=bool(stroke))
def line(x1,y1,x2,y2,color=ORANGE,width=2):
 c.setStrokeColor(color);c.setLineWidth(width);c.line(x1,H-y1,x2,H-y2)
def arrow(x1,y1,x2,y2):
 import math
 line(x1,y1,x2,y2)
 a=math.atan2(y2-y1,x2-x1)
 for da in [-.55,.55]:line(x2,y2,x2-10*math.cos(a+da),y2-10*math.sin(a+da))
def dot(n,x,y,r=12):
 c.setFillColor(ORANGE);c.circle(x,H-y,r,fill=1,stroke=0)
 c.setFillColor(white);c.setFont('ArialBold',11);c.drawCentredString(x,H-y-4,str(n))
def page(n,title,lead):
 c.setFillColor(CREAM);c.rect(0,0,W,H,fill=1,stroke=0)
 text(40,27,'TileForge',13,bold=True);text(126,30,'VISUAL USER GUIDE',8.5,MUTED)
 text(40,66,f'{n:02d}',28,ORANGE,bold=True);text(100,66,title,28,bold=True)
 para(100,105,lead,700,11.5,MUTED)
 line(40,143,802,143,LINE,1)
 line(40,553,802,553,LINE,1)
 text(40,568,'TileForge 1.0  /  macOS 14+  /  Apple Silicon',8.5,MUTED)
 text(746,568,f'{n:02d} / 09',8.5,MUTED)
 c.bookmarkPage(f'step{n}');c.addOutlineEntry(f'{n}. {title}',f'step{n}',level=0,closed=False)
def finish():c.showPage()
def note(value,top=497,width=465):
 box(40,top,width,43,fill=HexColor('#EAE3DA'),r=7);para(52,top+9,value,width-24,10.5,MUTED)
def steps(items,x=555,top=172,width=245):
 y=top
 for i,(heading,body) in enumerate(items,1):
  dot(i,x+11,y+10,11);h=para(x+31,y,heading,width-31,13,bold=True);y+=h+6
  y+=para(x+31,y,body,width-31,11.5,MUTED)+20
 return y

def picture(name,x,top,w,*,crop=None,highlights=(),caption=None):
 image=Image.open(SCREENS/name).convert('RGB')
 pixel_scale=image.width/1280
 if crop:image=image.crop(tuple(int(v*pixel_scale) for v in crop))
 iw,ih=image.size;h=w*ih/iw
 c.drawImage(ImageReader(image),x,H-top-h,width=w,height=h)
 for n,rect in highlights:
  rx,ry,rw,rh=rect
  ox,oy=crop[:2] if crop else (0,0)
  xx=x+(rx-ox)*pixel_scale*w/iw;yy=top+(ry-oy)*pixel_scale*w/iw
  c.setStrokeColor(ORANGE);c.setLineWidth(2.2);c.roundRect(xx,H-yy-rh*pixel_scale*w/iw,rw*pixel_scale*w/iw,rh*pixel_scale*w/iw,4,fill=0,stroke=1)
  dot(n,xx+rw*pixel_scale*w/iw-4,yy-5,11)
 if caption:text(x,top+h+8,caption,8.5,MUTED)
 return h

def labeled_card(x,top,w,h,title,sub):
 box(x,top,w,h,white,LINE);text(x+15,top+15,title,13,bold=True);para(x+15,top+39,sub,w-30,11,MUTED)

# 1 - Installation diagram. No fake Finder screenshot.
page(1,'Install and open','Open the DMG, drag the app to Applications, then launch it.')
box(40,168,465,310,white,LINE)
text(60,186,'INSTALLATION DIAGRAM',9,MUTED,bold=True)
box(70,226,148,74,CREAM,LINE);text(88,247,'TileForge.dmg',16,bold=True);text(88,272,'Double-click',11,MUTED)
arrow(228,263,296,263)
c.drawImage(str(ROOT/'docs/guide/examples/app-icon.png'),318,H-209-96,96,96,mask='auto')
text(306,318,'TileForge.app',14,bold=True)
arrow(365,345,365,384)
box(241,397,225,57,HexColor('#EAE3DA'));text(262,413,'Applications',18,bold=True);text(262,437,'Applications folder',10,MUTED)
steps([('Open the DMG','Double-click the downloaded <b>TileForge.dmg</b> file.'),('Move the app','Drag <b>TileForge.app</b> onto the <b>Applications</b> shortcut in the window.'),('Open TileForge','Launch TileForge from the Applications folder.')])
note('Requires an Apple Silicon Mac (M1 or later) running macOS 14 or later.')
finish()
# 2 - Google OAuth.
page(2,'Sign in with Google','Sign in on the official OpenAI page in your browser. The app never asks for your password.')
picture('01-login.png',40,170,465,crop=(14,70,282,213),highlights=[(1,(31,117,155,24))],caption='Account panel in the app.')
text(40,446,'CONTINUE IN YOUR BROWSER',9,MUTED,bold=True)
for x,title,sub in [(40,'OpenAI','Official sign-in page'),(201,'Google','Continue with Google'),(362,'TileForge','Return to the app')]:
 box(x,469,143,64,white,LINE,r=7);text(x+12,480,title,12,bold=True);para(x+12,500,sub,119,9.5,MUTED)
arrow(185,500,198,500);arrow(346,500,359,500)
steps([('Sign in with Google','Click <b>Sign in with Google</b> in TileForge to open your browser.'),('Continue with Google','On the official OpenAI page, choose <b>Continue with Google</b>. Select the Google account linked to your ChatGPT plan.'),('Return to the app','Check for <b>ChatGPT connected</b>. Click <b>Refresh connection</b> if needed. Use <b>Switch Google account</b> to change accounts.')])
para(555,467,'An existing Codex session may connect automatically. Google may ask you to sign in and verify your account.',245,10.5,MUTED)
finish()
# 3 - Import.
page(3,'Choose your image','Your source file is preserved. Start with a PNG, JPEG, TIFF, HEIC or WebP image.')
picture('02-empty.png',40,170,465,crop=(15,207,281,317),highlights=[(1,(20,254,252,41))],caption='Choose image… opens the file picker. The selected file name and dimensions appear here.')
box(40,402,465,118,white,LINE)
c.drawImage(str(ROOT/'docs/guide/examples/reference.png'),57,H-416-90,width=135,height=90)
text(210,419,'Sample source',14,bold=True);text(210,446,'512 × 341 pixels',12,MUTED);para(210,470,'Choose your own photo or design.',271,11,MUTED)
steps([('Click Choose image…','Find your image in the file picker and click <b>Open</b>.'),('Or drag and drop','Drop an image file directly into the main workspace.'),('Check the file','The preview appears on the right. The file name and source dimensions appear on the left.')])
finish()
# 4 - Grid.
page(4,'Choose the tile grid','Start with 2×2. Each tile requires a separate GPT generation.')
picture('04-grid.png',40,170,465,crop=(14,353,282,497),highlights=[(1,(20,392,252,39)),(2,(19,435,181,31))],caption='Selecting 3×3 prepares nine tiles.')
for j,(cols,rows) in enumerate([(2,2),(2,3),(3,3),(4,4)]):
 x=40+j*120;y=453
 box(x,y,105,80,white,LINE,r=7)
 for i in range(1,cols):line(x+12+81*i/cols,y+10,x+12+81*i/cols,y+49,LINE,1)
 for i in range(1,rows):line(x+12,y+10+39*i/rows,x+93,y+10+39*i/rows,LINE,1)
 c.setStrokeColor(ORANGE);c.setLineWidth(1);c.rect(x+12,H-y-49,81,39,fill=0,stroke=1)
 text(x+12,y+60,f'{cols}×{rows} = {cols*rows} tiles',10,bold=True)
steps([('Choose a preset grid','<b>2×2 = 4</b>, <b>2×3 = 6</b>, <b>3×3 = 9</b>, <b>4×4 = 16</b> tiles. The first number is columns; the second is rows.'),('Set a custom grid','Use the arrows beside <b>Columns</b> and <b>Rows</b> to choose values from 1 to 8.'),('Check the preview lines','Dashed lines show the tile boundaries. Context from neighboring tiles is added automatically.')])
finish()
# 5 - Output settings.
page(5,'Set scale and detail','Start with 2× scale and the default 80% detail transfer, then adjust as needed.')
picture('03-source.png',40,166,315,crop=(14,500,282,741),highlights=[(1,(20,534,183,29)),(2,(20,570,252,44)),(3,(20,623,252,81))],caption='Enlarged settings panel from the app.')
box(376,166,129,284,white,LINE)
text(390,183,'EXAMPLE',9,MUTED,bold=True)
for y,a,b in [(213,'1×','512 × 341'),(279,'2×','1024 × 682'),(345,'4×','2048 × 1364')]:
 text(390,y,a,18,ORANGE,bold=True);text(390,y+26,b,10.5,MUTED)
steps([('Choose the scale','<b>1×</b> keeps the source size. <b>2×</b> doubles each dimension; <b>4×</b> quadruples it. Check the <b>Output</b> row for the target dimensions.'),('Adjust Detail transfer','The slider controls how much generated fine texture is blended into the result. Higher values do not always look better.'),('Write your instructions','For example: <i>“Preserve shapes and lighting; enhance fabric texture and fine surface details.”</i> You can enter up to 4,000 characters.')])
note('If the 48 MP warning appears, reduce the scale. Larger jobs need more memory and time.')
finish()
# 6 - Production.
page(6,'Enhance and compose','GPT generates each tile online. Completed tiles are saved in the job folder.')
picture('03-source.png',40,170,465,crop=(14,748,282,844),highlights=[(1,(20,769,252,47))],caption='Click to start generation.')
picture('05-progress.png',40,363,465,crop=(304,808,805,865),highlights=[(2,(312,816,225,23))],caption='The progress area shows the current tile and processing status.')
steps([('Start generation','Once your account, image and settings are ready, click <b>Enhance and compose</b>.'),('Follow progress','GPT processes tiles in sequence. Each tile may take a few minutes. The latest completed tile appears in the workspace.'),('Stop if needed','Click <b>Stop processing</b> to interrupt the job. Completed tiles are kept so you can resume later.')])
picture('05-progress.png',40,442,250,crop=(14,765,282,817),highlights=[(3,(20,771,252,42))])
note('Generations consume your ChatGPT/Codex usage allowance. No API key is required.')
finish()
# 7 - Review.
page(7,'Compare Before / After','Before saving, inspect lighting, object edges and tile joins closely.')
picture('06-result.png',40,170,465,crop=(889,10,1144,57),highlights=[(1,(913,18,61,29)),(2,(974,18,53,29))])
a=Image.open(ROOT/'docs/guide/examples/reference.png');b=Image.open(ROOT/'docs/guide/examples/result.png')
for x,image,label in [(40,a,'BEFORE · 512 × 341'),(280,b,'AFTER · 1024 × 682')]:
 h=215*image.height/image.width;c.drawImage(ImageReader(image),x,H-294-h,215,h);text(x,294+h+10,label,9,MUTED,bold=True)
steps([('Switch Before / After','Use <b>Before</b> and <b>After</b> in the top toolbar to compare the source and result.'),('Inspect at 100%','Use the magnifier buttons to zoom. <b>Fit</b> shows the whole image; 100% lets you inspect actual pixels.'),('Review the details','Check faces, text, fine lines and tile joins. Look for changes in shape and uneven lighting or tone.')])
note('GPT may change details and shapes. Seamless joins are not guaranteed for every image.')
finish()
# 8 - Export.
page(8,'Export the result','Save the result as PNG or TIFF under a new name to preserve your source file.')
picture('06-result.png',40,170,465,crop=(1132,9,1270,59),highlights=[(1,(1147,19,111,30))])
box(40,371,465,150,white,LINE)
text(58,386,'SAVE DIALOG DIAGRAM',9,MUTED,bold=True)
text(58,417,'File name',11,MUTED);box(154,406,329,34,CREAM,LINE,r=5);text(166,417,'TileForge-result.png',12)
text(58,459,'Folder',11,MUTED);text(154,459,'Your chosen save location',12)
box(365,477,118,29,ORANGE,r=6);text(390,484,'Save',12,white,bold=True)
steps([('Click Export','When the result is ready, <b>Export</b> becomes available at the top right.'),('Choose a name and location','In the save dialog, choose a folder and a new file name. Use <b>.png</b> for PNG or <b>.tiff</b> for TIFF.'),('Click Save','Open the exported file and check its dimensions. Shortcut: <b>Command + Shift + E</b>. A copy also stays in the job folder.')])
finish()
# 9 - Resume and quick troubleshooting.
page(9,'Resume a saved job','If the connection drops or you stop processing, resume without regenerating completed tiles.')
picture('03-source.png',40,170,465,crop=(14,811,282,843),highlights=[(1,(65,819,164,21))])
box(40,265,465,95,white,LINE)
text(58,281,'JOB FOLDER',9,MUTED,bold=True)
text(58,307,'job.json',18,ORANGE,bold=True);text(178,312,'Select this file to resume.',12)
text(58,337,'source.png   /   tile-01   /   tile-02   /   …',11,MUTED)
text(40,386,'QUICK FIXES',10,MUTED,bold=True)
for y,heading,body in [(414,'Start button unavailable','Check your connection, selected image and the 48 MP limit.'),(461,'Account not connected','Click Refresh connection; sign in with Google again if needed.'),(508,'Usage limit / connection error','Wait for your allowance or connection to recover, then resume.')]:
 text(40,y,heading,11,bold=True);para(40,y+17,body,465,10.5,MUTED)
steps([('Resume saved job…','Click this button at the bottom left, then find the job folder in the file picker.'),('Select job.json','Select the job record and click <b>Open</b>. The app reuses valid completed tiles.'),('Keep the job files','The folder icon at the bottom right opens the job files. Keep <b>job.json</b>, the source and tile folders together.')])
finish();c.save()
# Lightweight HTML companion: same pages as images, works offline and supports browser zoom.
import pymupdf as fitz
from html import escape
render=OUT/'Guide_Pages';render.mkdir(exist_ok=True)
doc=fitz.open(PDF)
for i,p in enumerate(doc):p.get_pixmap(matrix=fitz.Matrix(1.55,1.55),alpha=False).save(render/f'{i+1:02d}.png')
html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>TileForge - Visual User Guide</title><style>body{margin:0;background:#292b2d;color:#eee;font:16px system-ui}header{padding:22px;position:sticky;top:0;background:#1c2024}header a{color:#ffab7b;margin-right:12px}main{max-width:1200px;margin:22px auto}img{display:block;width:100%;height:auto;margin:18px 0;border-radius:8px}section{scroll-margin-top:90px}p{line-height:1.5}</style><header><b>TileForge · Step-by-step guide</b><p>'''
for i in range(1,10):html+=f'<a href="#s{i}">{i}</a>'
html+='</p></header><main>'
for i in range(1,10):html+=f'<section id="s{i}"><img src="Guide_Pages/{i:02d}.png" alt="TileForge visual user guide, step {i}"></section>'
html+='</main></html>'
(OUT/'TileForge_Visual_Guide.html').write_text(html,encoding='utf-8')
print(PDF)
