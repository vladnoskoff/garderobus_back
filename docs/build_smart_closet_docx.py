"""Generate a formatted Word document for the Garderobus strategy."""
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from xml.sax.saxutils import escape
from zipfile import ZipFile, ZIP_DEFLATED

DOCX_PATH = Path(__file__).with_name("smart_closet_strategy.docx")

CONTENT_TYPES = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<Types xmlns='http://schemas.openxmlformats.org/package/2006/content-types'>
  <Default Extension='rels' ContentType='application/vnd.openxmlformats-package.relationships+xml'/>
  <Default Extension='xml' ContentType='application/xml'/>
  <Override PartName='/docProps/app.xml' ContentType='application/vnd.openxmlformats-officedocument.extended-properties+xml'/>
  <Override PartName='/docProps/core.xml' ContentType='application/vnd.openxmlformats-package.core-properties+xml'/>
  <Override PartName='/word/document.xml' ContentType='application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml'/>
  <Override PartName='/word/styles.xml' ContentType='application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml'/>
  <Override PartName='/word/numbering.xml' ContentType='application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml'/>
</Types>
"""

RELS = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'>
  <Relationship Id='rId1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument' Target='word/document.xml'/>
</Relationships>
"""

STYLES = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<w:styles xmlns:w='http://schemas.openxmlformats.org/wordprocessingml/2006/main'>
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii='Calibri' w:eastAsia='Calibri' w:hAnsi='Calibri' w:cs='Calibri'/>
        <w:sz w:val='22'/>
        <w:szCs w:val='22'/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after='160'/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type='paragraph' w:default='1' w:styleId='Normal'>
    <w:name w:val='Normal'/>
    <w:qFormat/>
  </w:style>
  <w:style w:type='paragraph' w:styleId='Title'>
    <w:name w:val='Title'/>
    <w:basedOn w:val='Normal'/>
    <w:next w:val='Normal'/>
    <w:uiPriority w:val='10'/>
    <w:qFormat/>
    <w:pPr>
      <w:jc w:val='center'/>
      <w:spacing w:after='240'/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii='Calibri Light' w:hAnsi='Calibri Light'/>
      <w:b/>
      <w:sz w:val='48'/>
      <w:szCs w:val='48'/>
    </w:rPr>
  </w:style>
  <w:style w:type='paragraph' w:styleId='Subtitle'>
    <w:name w:val='Subtitle'/>
    <w:basedOn w:val='Normal'/>
    <w:next w:val='Normal'/>
    <w:uiPriority w:val='11'/>
    <w:qFormat/>
    <w:pPr>
      <w:jc w:val='center'/>
      <w:spacing w:after='200'/>
    </w:pPr>
    <w:rPr>
      <w:sz w:val='28'/>
      <w:szCs w:val='28'/>
      <w:color w:val='5B9BD5'/>
    </w:rPr>
  </w:style>
  <w:style w:type='paragraph' w:styleId='Heading1' w:customStyle='1'>
    <w:name w:val='Heading 1'/>
    <w:basedOn w:val='Normal'/>
    <w:next w:val='Normal'/>
    <w:uiPriority w:val='9'/>
    <w:qFormat/>
    <w:pPr>
      <w:spacing w:before='320' w:after='160'/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:color w:val='1F4E79'/>
      <w:sz w:val='32'/>
      <w:szCs w:val='32'/>
    </w:rPr>
  </w:style>
  <w:style w:type='paragraph' w:styleId='Heading2' w:customStyle='1'>
    <w:name w:val='Heading 2'/>
    <w:basedOn w:val='Normal'/>
    <w:next w:val='Normal'/>
    <w:uiPriority w:val='9'/>
    <w:qFormat/>
    <w:pPr>
      <w:spacing w:before='240' w:after='120'/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:color w:val='2F5597'/>
      <w:sz w:val='28'/>
      <w:szCs w:val='28'/>
    </w:rPr>
  </w:style>
  <w:style w:type='paragraph' w:styleId='ListParagraph'>
    <w:name w:val='List Paragraph'/>
    <w:basedOn w:val='Normal'/>
    <w:uiPriority w:val='34'/>
    <w:qFormat/>
    <w:pPr>
      <w:ind w:left='720' w:hanging='360'/>
      <w:spacing w:after='120'/>
    </w:pPr>
  </w:style>
</w:styles>
"""

NUMBERING = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<w:numbering xmlns:w='http://schemas.openxmlformats.org/wordprocessingml/2006/main'>
  <w:abstractNum w:abstractNumId='0'>
    <w:multiLevelType w:val='hybridMultilevel'/>
    <w:lvl w:ilvl='0'>
      <w:start w:val='1'/>
      <w:numFmt w:val='bullet'/>
      <w:lvlText w:val='•'/>
      <w:lvlJc w:val='left'/>
      <w:pPr>
        <w:ind w:left='720' w:hanging='360'/>
      </w:pPr>
      <w:rPr>
        <w:rFonts w:ascii='Symbol' w:hAnsi='Symbol' w:hint='default'/>
      </w:rPr>
    </w:lvl>
    <w:lvl w:ilvl='1'>
      <w:start w:val='1'/>
      <w:numFmt w:val='bullet'/>
      <w:lvlText w:val='o'/>
      <w:lvlJc w:val='left'/>
      <w:pPr>
        <w:ind w:left='1440' w:hanging='360'/>
      </w:pPr>
      <w:rPr>
        <w:rFonts w:ascii='Courier New' w:hAnsi='Courier New'/>
      </w:rPr>
    </w:lvl>
  </w:abstractNum>
  <w:abstractNum w:abstractNumId='1'>
    <w:multiLevelType w:val='hybridMultilevel'/>
    <w:lvl w:ilvl='0'>
      <w:start w:val='1'/>
      <w:numFmt w:val='decimal'/>
      <w:lvlText w:val='%1.'/>
      <w:lvlJc w:val='left'/>
      <w:pPr>
        <w:ind w:left='720' w:hanging='360'/>
      </w:pPr>
    </w:lvl>
  </w:abstractNum>
  <w:num w:numId='1'>
    <w:abstractNumId w:val='0'/>
  </w:num>
  <w:num w:numId='2'>
    <w:abstractNumId w:val='1'/>
  </w:num>
</w:numbering>
"""

APP_PROPS = """<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<Properties xmlns='http://schemas.openxmlformats.org/officeDocument/2006/extended-properties' xmlns:vt='http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes'>
  <Application>Microsoft Word</Application>
  <DocSecurity>0</DocSecurity>
  <ScaleCrop>0</ScaleCrop>
  <HeadingPairs>
    <vt:vector size='2' baseType='variant'>
      <vt:variant>
        <vt:lpstr>Title</vt:lpstr>
      </vt:variant>
      <vt:variant>
        <vt:i4>1</vt:i4>
      </vt:variant>
    </vt:vector>
  </HeadingPairs>
  <TitlesOfParts>
    <vt:vector size='1' baseType='lpstr'>
      <vt:lpstr>Стратегия стартапа Garderobus</vt:lpstr>
    </vt:vector>
  </TitlesOfParts>
  <Company>Garderobus</Company>
  <LinksUpToDate>0</LinksUpToDate>
  <CharactersWithSpaces>0</CharactersWithSpaces>
  <SharedDoc>0</SharedDoc>
  <HyperlinksChanged>0</HyperlinksChanged>
  <AppVersion>16.0000</AppVersion>
</Properties>
"""


def build_core_properties() -> str:
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    return (
        "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>\n"
        "<cp:coreProperties xmlns:cp='http://schemas.openxmlformats.org/package/2006/metadata/core-properties' "
        "xmlns:dc='http://purl.org/dc/elements/1.1/' xmlns:dcterms='http://purl.org/dc/terms/' "
        "xmlns:dcmitype='http://purl.org/dc/dcmitype/' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>\n"
        "  <dc:title>Стратегия стартапа «Garderobus»</dc:title>\n"
        "  <dc:subject>Стратегия в четырёх координатах</dc:subject>\n"
        "  <dc:creator>Garderobus Team</dc:creator>\n"
        "  <cp:lastModifiedBy>Garderobus Team</cp:lastModifiedBy>\n"
        f"  <dcterms:created xsi:type='dcterms:W3CDTF'>{now}</dcterms:created>\n"
        f"  <dcterms:modified xsi:type='dcterms:W3CDTF'>{now}</dcterms:modified>\n"
        "</cp:coreProperties>\n"
    )


def run(text: str, *, bold: bool = False) -> str:
    text_escaped = escape(text)
    preserve = " xml:space='preserve'" if text_escaped.strip() != text_escaped else ""
    rpr = "<w:rPr><w:b/><w:bCs/></w:rPr>" if bold else ""
    return f"<w:r>{rpr}<w:t{preserve}>{text_escaped}</w:t></w:r>"


def paragraph(runs: list[tuple[str, bool]], *, style: str | None = None, num: int | None = None, ilvl: int = 0) -> str:
    ppr_segments: list[str] = []
    if style:
        ppr_segments.append(f"<w:pStyle w:val='{style}'/>")
    if num is not None:
        ppr_segments.append(f"<w:numPr><w:ilvl w:val='{ilvl}'/><w:numId w:val='{num}'/></w:numPr>")
    ppr = f"<w:pPr>{''.join(ppr_segments)}</w:pPr>" if ppr_segments else ""
    runs_xml = ''.join(run(text, bold=bold) for text, bold in runs)
    return f"<w:p>{ppr}{runs_xml}</w:p>"


def build_document_body() -> str:
    body: list[str] = []
    body.append(paragraph([( "Стратегия стартапа «Garderobus»", False)], style='Title'))
    body.append(paragraph([( "Платформа цифрового гардероба", False)], style='Subtitle'))

    body.append(paragraph([( "Формулировка темы диплома", False)], style='Heading1'))
    thesis_points = [
        (
            "Предлагаемая формулировка.",
            "«Разработка программного комплекса рекомендаций по выбору одежды на основе мониторинга и анализа окружающей среды».",
        ),
        (
            "Фокус на приложении.",
            "Основной результат — мобильное и облачное приложение Garderobus, объединяющее погодные данные из готовых API и датчиков партнёров.",
        ),
        (
            "Аппаратная часть — интеграции.",
            "Используем внешние метеостанции и сервисы как источники данных, поэтому диплом подчёркивает программную платформу без разработки собственного железа.",
        ),
    ]
    for title, desc in thesis_points:
        body.append(paragraph([(f"{title} ", True), (desc, False)], style='ListParagraph', num=1))

    body.append(paragraph([( "Задание", False)], style='Heading1'))
    body.append(paragraph([( "Разработать стратегию стартапа в четырёх координатах: тайминг, целевой клиент, целостный продукт, информационный поток.", False)]))

    body.append(paragraph([( "Контекст: почему «умный гардероб» актуален сейчас", False)], style='Heading1'))
    context_points = [
        ("Цифровизация быта.", "Ускоряется проникновение IoT и персональных ассистентов: умные колонки, фитнес-трекеры и интеллектуальные камеры становятся нормой в домохозяйствах мегаполисов."),
        ("Рост интереса к осознанному потреблению.", "Пользователи стремятся контролировать количество вещей и увеличивать срок службы одежды."),
        ("Гибридная занятость.", "После пандемии люди чаще работают из дома и комбинируют формальные и casual-образы — нужен инструмент, который помогает быстро подобрать подходящую комбинацию."),
        ("Экосистема fashion-tech.", "Бренды развивают цифровые каталоги, AR-примерки, сервисы перепродажи; платформе для персональной стилизации проще интегрироваться в эти каналы сейчас, чем 5 лет назад."),
    ]
    for title, desc in context_points:
        body.append(paragraph([(f"{title} ", True), (desc, False)], style='ListParagraph', num=1))

    body.append(paragraph([( "Четыре координаты успеха", False)], style='Heading1'))
    for item in ["Тайминг", "Целевой клиент", "Целостный продукт", "Информационный поток"]:
        body.append(paragraph([(item, False)], style='ListParagraph', num=1))

    body.append(paragraph([( "Тайминг", False)], style='Heading1'))
    timing_points = [
        ("Окно возможностей 2024–2026.", "Рынок умных домашних устройств растёт на ~11% CAGR, но сегмент персональных гардеробных ассистентов пока недостаточно заполнен — есть шанс занять нишу до прихода крупных игроков."),
        ("Порог массового интереса.", "Социальные сети и тикток-контент о капсульном гардеробе формируют устойчивый спрос: аудитория готова тестировать цифровые инструменты, если они решают ежедневные задачи."),
        ("Преодоление «пропасти».", "Пилотируем продукт на ранних последователях (urban millennials), собираем кейсы с экономией времени и бюджета, конвертируем в PR-истории для широкой аудитории."),
        ("Подушка на случай замедления рынка.", "Интеграции с ресейл-платформами и сервисами химчисток создают дополнительную ценность даже при снижении покупательской активности."),
    ]
    for title, desc in timing_points:
        body.append(paragraph([(f"{title} ", True), (desc, False)], style='ListParagraph', num=1))

    body.append(paragraph([( "Целевой клиент", False)], style='Heading1'))
    client_points = [
        ("Первичный сегмент.", "Жители крупных городов 25–40 лет, работающие в креативных или технологичных отраслях; доход средний и выше, активно пользуются мобильными сервисами, следят за трендами и экологичностью."),
        ("Болевые точки.", "Хаос в гардеробе, нехватка времени на подбор образов, сложности с управлением бюджетом на одежду, желание продлить жизнь вещам."),
        ("Ранние евангелисты.", "Фэшн-блогеры и стилисты, которым нужен инструмент для демонстрации образов и работы с клиентами."),
        ("География.", "Москва, Санкт-Петербург, затем расширение на города-миллионники и рынки Восточной Европы (Прага, Варшава) с похожими паттернами поведения."),
    ]
    for title, desc in client_points:
        body.append(paragraph([(f"{title} ", True), (desc, False)], style='ListParagraph', num=1))

    body.append(paragraph([( "Целостный продукт", False)], style='Heading1'))
    body.append(paragraph([( "Базовая ценность. ", True), ("Приложение и API для каталогизации одежды, рекомендаций луков, учёта локаций хранения и погодных условий.", False)], style='ListParagraph', num=1))

    body.append(paragraph([( "Дополнительные модули", False)], style='Heading2'))
    module_points = [
        "Интеграции с онлайн-магазинами и ресейл-платформами для автоматической синхронизации покупок.",
        "Партнёрские предложения с химчистками и ателье (заказ услуг из приложения).",
        "Режим стилиста: совместная работа над гардеробом с консультациями в чате.",
    ]
    for text in module_points:
        body.append(paragraph([(text, False)], style='ListParagraph', num=1, ilvl=1))

    extra_points = [
        ("Геймификация.", "Ачивки за оптимизацию гардероба, рекомендации капсульных коллекций, сравнение статистики с друзьями."),
        ("Монетизация.", "Freemium-модель: бесплатный базовый функционал, подписка на расширенную аналитику и персональные подборки; B2B-лицензии для стилистов и брендов."),
    ]
    for title, desc in extra_points:
        body.append(paragraph([(f"{title} ", True), (desc, False)], style='ListParagraph', num=1))

    body.append(paragraph([( "Информационный поток", False)], style='Heading1'))

    body.append(paragraph([( "Контент-стратегия", False)], style='Heading2'))
    content_points = [
        "Экосистема блогов и коротких видео о капсульном гардеробе, sustainability и цифровизации моды.",
        "Совместные рубрики с fashion-экспертами и брендами, демонстрирующие реальные кейсы оптимизации гардероба.",
    ]
    for text in content_points:
        body.append(paragraph([(text, False)], style='ListParagraph', num=1, ilvl=1))

    body.append(paragraph([( "Платформа комьюнити", False)], style='Heading2'))
    body.append(paragraph([( "Встроенный feed с образами пользователей, рейтинги, челленджи «30 дней без новых покупок» с возможностью делиться результатами в соцсетях.", False)], style='ListParagraph', num=1))

    body.append(paragraph([( "Данные и рекомендации", False)], style='Heading2'))
    body.append(paragraph([( "Персонализированные дайджесты: «что надеть сегодня», «что давно не носили», «что пора отдать/продать»; push-уведомления, завязанные на погоде и календаре.", False)], style='ListParagraph', num=1))

    body.append(paragraph([( "PR и партнёрства", False)], style='Heading2'))
    body.append(paragraph([( "Лонгриды о digital wardrobe management в деловых медиа, участие в fashion-tech конференциях, кейсы с устойчивыми брендами и ресейл-проектами.", False)], style='ListParagraph', num=1))

    body.append(paragraph([( "Дорожная карта внедрения", False)], style='Heading1'))
    roadmap_steps = [
        "Q2 2024 — MVP. Каталог вещей, ручной ввод, базовые рекомендации, Telegram-бот для обратной связи.",
        "Q3 2024 — Интеграции. Импорт чеков из почты, партнёрство с химчистками, запуск программы лояльности для блогеров.",
        "Q4 2024 — Машинное обучение. Персональные рекомендации, кластеризация образов, прогноз спроса на услуги.",
        "2025 — Масштабирование. Выход в новые регионы, локализация, B2B-кабинет для брендов и стилистов, API для смарт-зеркал.",
    ]
    for step in roadmap_steps:
        body.append(paragraph([(step, False)], style='ListParagraph', num=2))

    body.append(paragraph([( "Показатели успеха", False)], style='Heading1'))
    metrics = [
        "50 000 активных пользователей к концу 2025 года.",
        "30% retention на 3-м месяце.",
        "20 партнёрств с fashion-ритейлом, ресейлом и сервисами ухода.",
        "15% выручки от B2B-клиентов.",
    ]
    for metric in metrics:
        body.append(paragraph([(metric, False)], style='ListParagraph', num=1))

    body.append(paragraph([( "Риски и способы их снижения", False)], style='Heading1'))
    risks = [
        ("Конкуренция со стороны экосистем.", "Фокус на API-интеграциях и white-label-моделях для брендов, чтобы стать инфраструктурой, а не просто приложением."),
        ("Опасения пользователей по поводу приватности.", "Прозрачная политика хранения данных, end-to-end шифрование фотографий, офлайн-режим."),
        ("Низкая вовлечённость.", "Геймификация, регулярные контентные кампании, коллаборации с лидерами мнений."),
    ]
    for title, desc in risks:
        body.append(paragraph([(f"{title} ", True), (desc, False)], style='ListParagraph', num=1))

    body.append(paragraph([( "Вывод", False)], style='Heading1'))
    body.append(paragraph([( "«Garderobus» занимает окно возможностей на стыке fashion-tech и умного дома, предлагая целостный продукт, который решает ежедневные задачи аудитории, усиливается партнёрствами и подкрепляется осмысленным информационным потоком.", False)]))

    return ''.join(body)


def build_document() -> str:
    body = build_document_body()
    return (
        "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>\n"
        "<w:document xmlns:wpc='http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas' xmlns:mc='http://schemas.openxmlformats.org/markup-compatibility/2006' "
        "xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships' "
        "xmlns:m='http://schemas.openxmlformats.org/officeDocument/2006/math' xmlns:v='urn:schemas-microsoft-com:vml' "
        "xmlns:wp14='http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing' xmlns:wp='http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing' "
        "xmlns:w10='urn:schemas-microsoft-com:office:word' xmlns:w='http://schemas.openxmlformats.org/wordprocessingml/2006/main' "
        "xmlns:w14='http://schemas.microsoft.com/office/word/2010/wordml' xmlns:wpg='http://schemas.microsoft.com/office/word/2010/wordprocessingGroup' "
        "xmlns:wpi='http://schemas.microsoft.com/office/word/2010/wordprocessingInk' xmlns:wne='http://schemas.microsoft.com/office/word/2006/wordml' "
        "xmlns:wps='http://schemas.microsoft.com/office/word/2010/wordprocessingShape' mc:Ignorable='w14 wp14'>\n"
        "  <w:body>\n"
        f"    {body}\n"
        "    <w:sectPr>\n"
        "      <w:pgSz w:w='11906' w:h='16838'/>\n"
        "      <w:pgMar w:top='1440' w:right='1440' w:bottom='1440' w:left='1440' w:header='708' w:footer='708' w:gutter='0'/>\n"
        "      <w:cols w:space='708'/>\n"
        "      <w:docGrid w:linePitch='360'/>\n"
        "    </w:sectPr>\n"
        "  </w:body>\n"
        "</w:document>\n"
    )


def write_docx(path: Path) -> None:
    document = build_document()
    core = build_core_properties()
    with ZipFile(path, "w", ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", CONTENT_TYPES)
        archive.writestr("_rels/.rels", RELS)
        archive.writestr("word/document.xml", document)
        archive.writestr("word/styles.xml", STYLES)
        archive.writestr("word/numbering.xml", NUMBERING)
        archive.writestr("docProps/core.xml", core)
        archive.writestr("docProps/app.xml", APP_PROPS)


if __name__ == "__main__":
    write_docx(DOCX_PATH)
    print(f"Saved Word document to {DOCX_PATH}")
