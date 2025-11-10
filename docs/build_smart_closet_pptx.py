"""Generate a Garderobus strategy presentation (PPTX) without external dependencies."""
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple
from xml.sax.saxutils import escape
from zipfile import ZIP_DEFLATED, ZipFile

OUTPUT_PATH = Path(__file__).with_name("smart_closet_strategy.pptx")
TITLE = "Стратегия стартапа «Garderobus»"
SUBTITLE = "Программный комплекс рекомендаций по выбору одежды"


def _flatten_items(items: Iterable[object], level: int = 0) -> List[Tuple[str, int]]:
    flat: List[Tuple[str, int]] = []
    for item in items:
        if isinstance(item, tuple):
            text, nested = item
            flat.append((str(text), level))
            flat.extend(_flatten_items(nested, level + 1))
        elif isinstance(item, list):
            flat.extend(_flatten_items(item, level + 1))
        else:
            flat.append((str(item), level))
    return flat


def _bullet_paragraph(text: str, level: int) -> str:
    size = "3200" if level == 0 else "3000"
    bullet_char = "•" if level == 0 else "◦"
    return f"""
    <a:p>
      <a:pPr lvl='{level}'>
        <a:buChar char='{bullet_char}'/>
        <a:defRPr sz='{size}'>
          <a:solidFill><a:srgbClr val='242424'/></a:solidFill>
          <a:latin typeface='Calibri'/>
        </a:defRPr>
      </a:pPr>
      <a:r>
        <a:rPr lang='ru-RU' sz='{size}'>
          <a:solidFill><a:srgbClr val='242424'/></a:solidFill>
          <a:latin typeface='Calibri'/>
        </a:rPr>
        <a:t>{escape(text)}</a:t>
      </a:r>
      <a:endParaRPr lang='ru-RU' sz='{size}'/>
    </a:p>
    """.strip()


def _title_paragraph(text: str, *, size: int = 4800, color: str = "1F4E79", align: str = "ctr") -> str:
    return f"""
    <a:p>
      <a:pPr algn='{align}'>
        <a:defRPr sz='{size}' b='1'>
          <a:solidFill><a:srgbClr val='{color}'/></a:solidFill>
          <a:latin typeface='Calibri Light'/>
        </a:defRPr>
      </a:pPr>
      <a:r>
        <a:rPr lang='ru-RU' sz='{size}' b='1'>
          <a:solidFill><a:srgbClr val='{color}'/></a:solidFill>
          <a:latin typeface='Calibri Light'/>
        </a:rPr>
        <a:t>{escape(text)}</a:t>
      </a:r>
      <a:endParaRPr lang='ru-RU' sz='{size}'/>
    </a:p>
    """.strip()


def _subtitle_paragraph(text: str) -> str:
    return f"""
    <a:p>
      <a:pPr algn='ctr'>
        <a:defRPr sz='3600'>
          <a:solidFill><a:srgbClr val='5B9BD5'/></a:solidFill>
          <a:latin typeface='Calibri'/>
        </a:defRPr>
      </a:pPr>
      <a:r>
        <a:rPr lang='ru-RU' sz='3600'>
          <a:solidFill><a:srgbClr val='5B9BD5'/></a:solidFill>
          <a:latin typeface='Calibri'/>
        </a:rPr>
        <a:t>{escape(text)}</a:t>
      </a:r>
      <a:endParaRPr lang='ru-RU' sz='3600'/>
    </a:p>
    """.strip()


def _build_title_slide() -> str:
    return f"""<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<p:sld xmlns:a='http://schemas.openxmlformats.org/drawingml/2006/main'
       xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
       xmlns:p='http://schemas.openxmlformats.org/presentationml/2006/main'>
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id='1' name=''/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x='0' y='0'/>
          <a:ext cx='0' cy='0'/>
          <a:chOff x='0' y='0'/>
          <a:chExt cx='0' cy='0'/>
        </a:xfrm>
      </p:grpSpPr>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id='2' name='Title 1'/>
          <p:cNvSpPr>
            <a:spLocks noGrp='1'/>
          </p:cNvSpPr>
          <p:nvPr>
            <p:ph type='title'/>
          </p:nvPr>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x='685800' y='457200'/>
            <a:ext cx='10800000' cy='1181100'/>
          </a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:bodyPr anchor='ctr'/>
          <a:lstStyle/>
          {_title_paragraph(TITLE)}
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id='3' name='Subtitle 2'/>
          <p:cNvSpPr>
            <a:spLocks noGrp='1'/>
          </p:cNvSpPr>
          <p:nvPr>
            <p:ph type='subTitle'/>
          </p:nvPr>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x='914400' y='1676400'/>
            <a:ext cx='9972000' cy='1181100'/>
          </a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:bodyPr anchor='ctr'/>
          <a:lstStyle/>
          {_subtitle_paragraph(SUBTITLE)}
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr>
    <a:masterClrMapping/>
  </p:clrMapOvr>
</p:sld>
"""


def _build_bullet_slide(slide_id: int, title: str, bullets: Sequence[Tuple[str, int]]) -> str:
    paragraphs = "\n".join(_bullet_paragraph(text, level) for text, level in bullets)
    return f"""<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<p:sld xmlns:a='http://schemas.openxmlformats.org/drawingml/2006/main'
       xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
       xmlns:p='http://schemas.openxmlformats.org/presentationml/2006/main'>
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id='1' name=''/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x='0' y='0'/>
          <a:ext cx='0' cy='0'/>
          <a:chOff x='0' y='0'/>
          <a:chExt cx='0' cy='0'/>
        </a:xfrm>
      </p:grpSpPr>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id='2' name='Title {slide_id}'/>
          <p:cNvSpPr>
            <a:spLocks noGrp='1'/>
          </p:cNvSpPr>
          <p:nvPr>
            <p:ph type='title'/>
          </p:nvPr>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x='685800' y='411480'/>
            <a:ext cx='10800000' cy='1143000'/>
          </a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:bodyPr anchor='ctr'/>
          <a:lstStyle/>
          {_title_paragraph(title, size=4400)}
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id='3' name='Content {slide_id}'/>
          <p:cNvSpPr>
            <a:spLocks noGrp='1'/>
          </p:cNvSpPr>
          <p:nvPr>
            <p:ph type='body' idx='1'/>
          </p:nvPr>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x='685800' y='1701800'/>
            <a:ext cx='10800000' cy='3962400'/>
          </a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap='square'/>
          <a:lstStyle/>
          {paragraphs}
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr>
    <a:masterClrMapping/>
  </p:clrMapOvr>
</p:sld>
"""


THEME_XML = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<a:theme xmlns:a='http://schemas.openxmlformats.org/drawingml/2006/main' name='Garderobus'>
  <a:themeElements>
    <a:clrScheme name='Garderobus'>
      <a:dk1><a:srgbClr val='1F4E79'/></a:dk1>
      <a:lt1><a:srgbClr val='FFFFFF'/></a:lt1>
      <a:dk2><a:srgbClr val='243746'/></a:dk2>
      <a:lt2><a:srgbClr val='EEF4FB'/></a:lt2>
      <a:accent1><a:srgbClr val='5B9BD5'/></a:accent1>
      <a:accent2><a:srgbClr val='A5A5A5'/></a:accent2>
      <a:accent3><a:srgbClr val='70AD47'/></a:accent3>
      <a:accent4><a:srgbClr val='FFC000'/></a:accent4>
      <a:accent5><a:srgbClr val='4472C4'/></a:accent5>
      <a:accent6><a:srgbClr val='264478'/></a:accent6>
      <a:hlink><a:srgbClr val='2F5597'/></a:hlink>
      <a:folHlink><a:srgbClr val='244062'/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name='Garderobus'>
      <a:majorFont>
        <a:latin typeface='Calibri Light'/>
        <a:ea typeface=''/>
        <a:cs typeface=''/>
      </a:majorFont>
      <a:minorFont>
        <a:latin typeface='Calibri'/>
        <a:ea typeface=''/>
        <a:cs typeface=''/>
      </a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name='Garderobus'>
      <a:fillStyleLst>
        <a:solidFill><a:schemeClr val='bg1'/></a:solidFill>
        <a:solidFill><a:schemeClr val='accent1'/></a:solidFill>
        <a:solidFill><a:schemeClr val='accent2'/></a:solidFill>
      </a:fillStyleLst>
      <a:lnStyleLst>
        <a:ln w='25400'><a:solidFill><a:schemeClr val='accent1'/></a:solidFill></a:ln>
        <a:ln w='25400'><a:solidFill><a:schemeClr val='accent2'/></a:solidFill></a:ln>
        <a:ln w='25400'><a:solidFill><a:schemeClr val='accent3'/></a:solidFill></a:ln>
      </a:lnStyleLst>
      <a:effectStyleLst>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
      </a:effectStyleLst>
      <a:bgFillStyleLst>
        <a:solidFill><a:schemeClr val='bg1'/></a:solidFill>
        <a:solidFill><a:schemeClr val='lt1'/></a:solidFill>
        <a:solidFill><a:schemeClr val='lt2'/></a:solidFill>
      </a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
</a:theme>
"""


SLIDE_MASTER_XML = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<p:sldMaster xmlns:a='http://schemas.openxmlformats.org/drawingml/2006/main'
            xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
            xmlns:p='http://schemas.openxmlformats.org/presentationml/2006/main'>
  <p:cSld name='Garderobus Master'>
    <p:bg>
      <p:bgPr>
        <a:solidFill>
          <a:schemeClr val='bg1'/>
        </a:solidFill>
      </p:bgPr>
    </p:bg>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id='1' name=''/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x='0' y='0'/>
          <a:ext cx='0' cy='0'/>
          <a:chOff x='0' y='0'/>
          <a:chExt cx='0' cy='0'/>
        </a:xfrm>
      </p:grpSpPr>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id='2' name='Title Placeholder'/>
          <p:cNvSpPr>
            <a:spLocks noGrp='1'/>
          </p:cNvSpPr>
          <p:nvPr>
            <p:ph type='title'/>
          </p:nvPr>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x='685800' y='365760'/>
            <a:ext cx='10800000' cy='1143000'/>
          </a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:bodyPr anchor='ctr'/>
          <a:lstStyle/>
          <a:p/>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id='3' name='Content Placeholder'/>
          <p:cNvSpPr>
            <a:spLocks noGrp='1'/>
          </p:cNvSpPr>
          <p:nvPr>
            <p:ph type='body' idx='1'/>
          </p:nvPr>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x='685800' y='1701800'/>
            <a:ext cx='10800000' cy='3962400'/>
          </a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap='square'/>
          <a:lstStyle/>
          <a:p/>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr>
    <a:masterClrMapping/>
  </p:clrMapOvr>
  <p:sldLayoutIdLst>
    <p:sldLayoutId id='2147483649' r:id='rId1'/>
  </p:sldLayoutIdLst>
</p:sldMaster>
"""


SLIDE_MASTER_RELS = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'>
  <Relationship Id='rId1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout' Target='../slideLayouts/slideLayout1.xml'/>
  <Relationship Id='rId2' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme' Target='../theme/theme1.xml'/>
</Relationships>
"""


SLIDE_LAYOUT_XML = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<p:sldLayout xmlns:a='http://schemas.openxmlformats.org/drawingml/2006/main'
            xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
            xmlns:p='http://schemas.openxmlformats.org/presentationml/2006/main'
            type='titleAndContent' preserve='1'>
  <p:cSld name='Title and Content'>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id='1' name=''/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x='0' y='0'/>
          <a:ext cx='0' cy='0'/>
          <a:chOff x='0' y='0'/>
          <a:chExt cx='0' cy='0'/>
        </a:xfrm>
      </p:grpSpPr>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id='2' name='Title Placeholder'/>
          <p:cNvSpPr>
            <a:spLocks noGrp='1'/>
          </p:cNvSpPr>
          <p:nvPr>
            <p:ph type='title'/>
          </p:nvPr>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x='685800' y='411480'/>
            <a:ext cx='10800000' cy='1143000'/>
          </a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:bodyPr anchor='ctr'/>
          <a:lstStyle/>
          <a:p/>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id='3' name='Content Placeholder'/>
          <p:cNvSpPr>
            <a:spLocks noGrp='1'/>
          </p:cNvSpPr>
          <p:nvPr>
            <p:ph type='body' idx='1'/>
          </p:nvPr>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x='685800' y='1701800'/>
            <a:ext cx='10800000' cy='3962400'/>
          </a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap='square'/>
          <a:lstStyle/>
          <a:p/>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr>
    <a:masterClrMapping/>
  </p:clrMapOvr>
</p:sldLayout>
"""


CONTENT_TYPES_TEMPLATE = """<?xml version='1.0' encoding='UTF-8'?>
<Types xmlns='http://schemas.openxmlformats.org/package/2006/content-types'>
  <Default Extension='rels' ContentType='application/vnd.openxmlformats-package.relationships+xml'/>
  <Default Extension='xml' ContentType='application/xml'/>
  <Override PartName='/docProps/app.xml' ContentType='application/vnd.openxmlformats-officedocument.extended-properties+xml'/>
  <Override PartName='/docProps/core.xml' ContentType='application/vnd.openxmlformats-package.core-properties+xml'/>
  <Override PartName='/ppt/presentation.xml' ContentType='application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml'/>
  <Override PartName='/ppt/slideMasters/slideMaster1.xml' ContentType='application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml'/>
  <Override PartName='/ppt/slideLayouts/slideLayout1.xml' ContentType='application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml'/>
  <Override PartName='/ppt/theme/theme1.xml' ContentType='application/vnd.openxmlformats-officedocument.theme+xml'/>
  {slide_overrides}
</Types>
"""


RELS_XML = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'>
  <Relationship Id='rId1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument' Target='ppt/presentation.xml'/>
  <Relationship Id='rId2' Type='http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties' Target='docProps/core.xml'/>
  <Relationship Id='rId3' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties' Target='docProps/app.xml'/>
</Relationships>
"""


APP_XML_TEMPLATE = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<Properties xmlns='http://schemas.openxmlformats.org/officeDocument/2006/extended-properties'
            xmlns:vt='http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes'>
  <Application>Garderobus Generator</Application>
  <DocSecurity>0</DocSecurity>
  <ScaleCrop>false</ScaleCrop>
  <HeadingPairs>
    <vt:vector size='2' baseType='variant'>
      <vt:variant><vt:lpstr>Slides</vt:lpstr></vt:variant>
      <vt:variant><vt:i4>{slide_count}</vt:i4></vt:variant>
    </vt:vector>
  </HeadingPairs>
  <TitlesOfParts>
    <vt:vector size='{slide_count}' baseType='lpstr'>
      {title_vector}
    </vt:vector>
  </TitlesOfParts>
  <LinksUpToDate>false</LinksUpToDate>
  <SharedDoc>false</SharedDoc>
  <HyperlinksChanged>false</HyperlinksChanged>
  <AppVersion>16.0000</AppVersion>
</Properties>
"""


CORE_XML_TEMPLATE = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<cp:coreProperties xmlns:cp='http://schemas.openxmlformats.org/package/2006/metadata/core-properties'
                   xmlns:dc='http://purl.org/dc/elements/1.1/'
                   xmlns:dcterms='http://purl.org/dc/terms/'
                   xmlns:dcmitype='http://purl.org/dc/dcmitype/'
                   xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>
  <dc:title>{title}</dc:title>
  <dc:subject>Стратегия Garderobus</dc:subject>
  <dc:creator>Garderobus Team</dc:creator>
  <cp:lastModifiedBy>Garderobus Generator</cp:lastModifiedBy>
  <dcterms:created xsi:type='dcterms:W3CDTF'>{created}</dcterms:created>
  <dcterms:modified xsi:type='dcterms:W3CDTF'>{created}</dcterms:modified>
  <cp:revision>1</cp:revision>
</cp:coreProperties>
"""


PRESENTATION_XML_TEMPLATE = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<p:presentation xmlns:a='http://schemas.openxmlformats.org/drawingml/2006/main'
                xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
                xmlns:p='http://schemas.openxmlformats.org/presentationml/2006/main'>
  <p:sldMasterIdLst>
    <p:sldMasterId id='2147483648' r:id='rId1'/>
  </p:sldMasterIdLst>
  <p:sldIdLst>
    {slide_ids}
  </p:sldIdLst>
  <p:sldSz cx='12192000' cy='6858000' type='screen4x3'/>
  <p:notesSz cx='6858000' cy='9144000'/>
</p:presentation>
"""


PRESENTATION_RELS_TEMPLATE = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'>
  <Relationship Id='rId1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster' Target='slideMasters/slideMaster1.xml'/>
  {slide_relationships}
</Relationships>
"""


SLIDES_DATA = [
    (
        "Формулировка темы диплома",
        [
            "Предлагаемая формулировка: «Разработка программного комплекса рекомендаций по выбору одежды на основе мониторинга и анализа окружающей среды»",
            "Фокус на приложении: Garderobus объединяет погодные данные из готовых API и датчиков партнёров",
            "Аппаратная часть — интеграции с внешними метеостанциями, без разработки собственного железа",
            "Цифровой манекен визуализирует образы из вещей пользователя под текущую погоду",
        ],
    ),
    (
        "Контекст: почему «умный гардероб» актуален сейчас",
        [
            "Цифровизация быта и рост IoT-ассистентов в домохозяйствах",
            "Интерес к осознанному потреблению и продлению жизни вещей",
            "Гибридная занятость требует гибких wardrobe-решений",
            "Fashion-tech экосистема готова к интеграциям с персональными сервисами",
        ],
    ),
    (
        "Четыре координаты успеха",
        [
            "Тайминг",
            "Целевой клиент",
            "Целостный продукт",
            "Информационный поток",
        ],
    ),
    (
        "Тайминг",
        [
            "Окно 2024–2026: сегмент персональных ассистентов свободен",
            "Порог массового интереса благодаря TikTok и контенту о капсульных гардеробах",
            "Преодоление пропасти: пилоты с urban millennials и PR-кейсы",
            "Запас прочности: партнёрства с ресейл и сервисами ухода",
        ],
    ),
    (
        "Целевой клиент",
        [
            "Первичный сегмент: жители мегаполисов 25–40 лет в креативных сферах",
            "Болевые точки: хаос, нехватка времени, контроль бюджета, продление жизни вещей",
            "Ранние евангелисты: фэшн-блогеры и стилисты для демонстрации образов",
            "География: Москва, Петербург, расширение в города-миллионники и Восточную Европу",
        ],
    ),
    (
        "Целостный продукт",
        [
            "Базовая ценность: каталогизация, рекомендации образов, учёт хранения и погоды",
            (
                "Дополнительные модули",
                [
                    "Интеграции с онлайн-магазинами и ресейл-платформами",
                    "Партнёрские предложения химчисток и ателье",
                    "Режим стилиста с совместной работой и чатом",
                ],
            ),
            "Геймификация: ачивки, капсульные коллекции, сравнение статистики",
            "Монетизация: freemium + подписка + B2B-лицензии",
        ],
    ),
    (
        "Информационный поток",
        [
            (
                "Контент-стратегия",
                [
                    "Блоги и короткие видео про sustainability и цифровизацию моды",
                    "Рубрики с экспертами и брендами с реальными кейсами",
                ],
            ),
            "Комьюнити-платформа с челленджами и социальным шэрингом",
            "Персональные дайджесты: что надеть, что давно не носили, что продать",
            "PR и партнёрства: лонгриды, конференции, кейсы с устойчивыми брендами",
        ],
    ),
    (
        "Дорожная карта внедрения",
        [
            "Q2 2024 — MVP: каталог, ручной ввод, базовые рекомендации, Telegram-бот",
            "Q3 2024 — интеграции: импорт чеков, химчистки, лояльность для блогеров",
            "Q4 2024 — ML: персональные рекомендации, кластеризация образов, прогноз спроса",
            "2025 — масштабирование: регионы, локализация, B2B-кабинет, API для смарт-зеркал",
        ],
    ),
    (
        "Показатели успеха",
        [
            "50 000 активных пользователей к концу 2025",
            "30% retention на 3-м месяце",
            "20 партнёрств с fashion-ритейлом, ресейлом и сервисами ухода",
            "15% выручки от B2B-клиентов",
        ],
    ),
    (
        "Риски и способы снижения",
        [
            "Конкуренция экосистем: фокус на API и white-label для брендов",
            "Приватность: прозрачная политика, шифрование фото, офлайн-режим",
            "Вовлечённость: геймификация, контентные кампании, коллаборации лидеров мнений",
        ],
    ),
    (
        "Вывод",
        [
            "Garderobus занимает окно возможностей между fashion-tech и умным домом",
            "Продукт закрывает ежедневные задачи и усиливается партнёрствами",
            "Сбалансированный информационный поток поддерживает рост и удержание",
        ],
    ),
]


def build_presentation(output_path: Path = OUTPUT_PATH) -> Path:
    slides_xml: List[str] = [_build_title_slide()]
    for index, (title, items) in enumerate(SLIDES_DATA, start=2):
        bullets = _flatten_items(items)
        slides_xml.append(_build_bullet_slide(index, title, bullets))

    slide_count = len(slides_xml)
    slide_overrides = "\n  ".join(
        f"<Override PartName='/ppt/slides/slide{idx + 1}.xml' ContentType='application/vnd.openxmlformats-officedocument.presentationml.slide+xml'/>"
        for idx in range(slide_count)
    )

    content_types = CONTENT_TYPES_TEMPLATE.format(slide_overrides=slide_overrides)

    slide_ids = "\n    ".join(
        f"<p:sldId id='{255 + idx}' r:id='rId{idx + 2}'/>" for idx in range(slide_count)
    )
    presentation_xml = PRESENTATION_XML_TEMPLATE.format(slide_ids=slide_ids)

    slide_relationships = "\n  ".join(
        f"<Relationship Id='rId{idx + 2}' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide' Target='slides/slide{idx + 1}.xml'/>"
        for idx in range(slide_count)
    )
    presentation_rels = PRESENTATION_RELS_TEMPLATE.format(slide_relationships=slide_relationships)

    titles = [TITLE] + [title for title, _ in SLIDES_DATA]
    title_vector = "\n      ".join(f"<vt:lpstr>{escape(text)}</vt:lpstr>" for text in titles)
    app_xml = APP_XML_TEMPLATE.format(slide_count=slide_count, title_vector=title_vector)

    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    core_xml = CORE_XML_TEMPLATE.format(title=TITLE, created=now)

    with ZipFile(output_path, "w", ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", content_types)
        archive.writestr("_rels/.rels", RELS_XML)
        archive.writestr("docProps/app.xml", app_xml)
        archive.writestr("docProps/core.xml", core_xml)
        archive.writestr("ppt/presentation.xml", presentation_xml)
        archive.writestr("ppt/_rels/presentation.xml.rels", presentation_rels)
        archive.writestr("ppt/theme/theme1.xml", THEME_XML)
        archive.writestr("ppt/slideMasters/slideMaster1.xml", SLIDE_MASTER_XML)
        archive.writestr("ppt/slideMasters/_rels/slideMaster1.xml.rels", SLIDE_MASTER_RELS)
        archive.writestr("ppt/slideLayouts/slideLayout1.xml", SLIDE_LAYOUT_XML)
        archive.writestr(
            "ppt/slideLayouts/_rels/slideLayout1.xml.rels",
            """<?xml version='1.0' encoding='UTF-8' standalone='yes'?><Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'>
</Relationships>""",
        )
        for idx, slide_xml in enumerate(slides_xml, start=1):
            archive.writestr(f"ppt/slides/slide{idx}.xml", slide_xml)

    return output_path


if __name__ == "__main__":
    path = build_presentation()
    print(f"Saved presentation to {path}")
