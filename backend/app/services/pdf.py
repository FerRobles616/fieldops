from datetime import UTC, datetime
from io import BytesIO
from typing import Any
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.lib.utils import ImageReader
from reportlab.platypus import (
    Flowable,
    Image,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

from app.models.work_order import WorkOrder
from app.models.work_order_photo import WorkOrderPhoto
from app.services.storage import StorageService


def _format_datetime(value: datetime | None) -> str:
    if value is None:
        return "Not scheduled"
    return value.strftime("%Y-%m-%d %H:%M")


def generate_work_order_pdf(
    work_order: WorkOrder,
    photos: list[WorkOrderPhoto],
    storage: StorageService,
) -> bytes:
    buffer = BytesIO()
    document = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=20 * mm,
        title=f"FieldOps work order {work_order.code}",
        author="FieldOps",
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "FieldOpsTitle",
        parent=styles["Title"],
        fontSize=20,
        leading=24,
        alignment=0,
        spaceAfter=4,
    )
    heading_style = ParagraphStyle(
        "FieldOpsHeading",
        parent=styles["Heading2"],
        fontSize=12,
        leading=15,
        spaceBefore=14,
        spaceAfter=6,
    )
    body_style = ParagraphStyle(
        "FieldOpsBody",
        parent=styles["BodyText"],
        fontSize=9.5,
        leading=13,
    )
    small_style = ParagraphStyle(
        "FieldOpsSmall",
        parent=styles["BodyText"],
        fontSize=8,
        leading=10,
        textColor=colors.grey,
    )

    story: list[Flowable] = [
        Paragraph("FieldOps", small_style),
        Spacer(1, 4),
        Paragraph(escape(work_order.code), title_style),
        Paragraph(escape(work_order.title), heading_style),
        Spacer(1, 6),
    ]

    details = [
        ["Status", work_order.status.value.replace("_", " ").title()],
        ["Priority", work_order.priority.value.title()],
        ["Customer", work_order.customer.name],
        ["Address", work_order.customer.address or "—"],
        ["Phone", work_order.customer.phone or "—"],
        [
            "Assigned to",
            work_order.assigned_to.name if work_order.assigned_to is not None else "Unassigned",
        ],
        ["Scheduled", _format_datetime(work_order.scheduled_at)],
        ["Updated", _format_datetime(work_order.updated_at)],
        ["Version", str(work_order.version)],
    ]
    table = Table(
        [
            [Paragraph(escape(str(label)), body_style), Paragraph(escape(str(value)), body_style)]
            for label, value in details
        ],
        colWidths=[35 * mm, 139 * mm],
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#F1F5F4")),
                ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#D6E2DF")),
                ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#E2EBE9")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.append(table)

    if work_order.description:
        story.append(Paragraph("Description", heading_style))
        story.append(
            Paragraph(
                escape(work_order.description).replace("\n", "<br/>"),
                body_style,
            )
        )

    if photos:
        story.append(Paragraph("Photos", heading_style))
        for photo in photos:
            try:
                data = storage.read(photo.storage_key)
                reader = ImageReader(BytesIO(data))
                image_width, image_height = reader.getSize()
            except Exception:
                continue

            max_width = 160 * mm
            max_height = 100 * mm
            width = min(max_width, image_width)
            height = image_height * width / image_width
            if height > max_height:
                height = max_height
                width = image_width * height / image_height

            story.append(
                Image(
                    BytesIO(data),
                    width=width,
                    height=height,
                )
            )
            if photo.caption:
                story.append(Spacer(1, 3))
                story.append(Paragraph(escape(photo.caption), small_style))
            story.append(Spacer(1, 8))

    story.append(Spacer(1, 12))
    story.append(
        Paragraph(
            f"Generated by FieldOps · {datetime.now(UTC).strftime('%Y-%m-%d %H:%M UTC')}",
            small_style,
        )
    )

    def draw_footer(canvas: Any, doc: Any) -> None:
        canvas.saveState()
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(colors.grey)
        canvas.drawString(
            18 * mm,
            12 * mm,
            f"FieldOps · {work_order.code}",
        )
        canvas.drawRightString(
            A4[0] - 18 * mm,
            12 * mm,
            f"Page {doc.page}",
        )
        canvas.restoreState()

    document.build(story, onFirstPage=draw_footer, onLaterPages=draw_footer)
    return buffer.getvalue()
