from collections import defaultdict
from io import BytesIO

from django.contrib.auth.decorators import login_required
from django.http import HttpResponse
from django.shortcuts import render
from django.utils.text import slugify
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.table import Table, TableStyleInfo

from marking.models import Project, WireEndpoint


@login_required(login_url="/admin/login/")
def cambrics_report(request):
    context = {}

    if request.method == "POST":
        project_id = request.POST.get("project_id", "").strip()
        order_number = request.POST.get("order_number", "").strip()

        context["project_id"] = project_id
        context["order_number"] = order_number

        try:
            project = Project.objects.get(project_id=project_id, order_number=order_number)
        except Project.DoesNotExist:
            context["error"] = "Проект с таким PROJECT_ID и ORDER_NUMBER не найден."
        except Project.MultipleObjectsReturned:
            context["error"] = "Найдено несколько проектов с таким PROJECT_ID и ORDER_NUMBER."
        else:
            return _build_cambrics_response(project)

    return render(request, "marking/cambrics_report.html", context)


def _build_cambrics_response(project):
    endpoints = list(
        WireEndpoint.objects.select_related("drawing")
        .filter(drawing__project=project)
        .order_by("drawing__dwg_id", "mark", "ref_id")
    )

    by_ref_id = defaultdict(list)
    for endpoint in endpoints:
        by_ref_id[endpoint.ref_id].append(endpoint)

    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Кембрики"

    sheet.append(["Проект", project.project_id])
    sheet.append(["Номер заказа", project.order_number])
    sheet.append(["Название", project.name])
    sheet.append([])

    headers = [
        "Чертеж",
        "Маркировка",
        "Куда идет",
        "REF_ID",
        "Позиция",
        "Тип провода",
        "Цвет",
    ]
    sheet.append(headers)

    for endpoint in endpoints:
        linked = [
            other
            for other in by_ref_id[endpoint.ref_id]
            if other.endpoint_id != endpoint.endpoint_id
        ]
        linked_marks = ", ".join(_endpoint_label(item) for item in linked)

        sheet.append(
            [
                endpoint.drawing.dwg_id,
                endpoint.mark,
                linked_marks,
                endpoint.ref_id,
                endpoint.position,
                endpoint.wire_type,
                endpoint.wire_color,
            ]
        )

    _format_cambrics_sheet(sheet, len(endpoints))

    output = BytesIO()
    workbook.save(output)
    output.seek(0)

    filename = _cambrics_filename(project)
    response = HttpResponse(
        output.getvalue(),
        content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )
    response["Content-Disposition"] = f'attachment; filename="{filename}"'
    return response


def _endpoint_label(endpoint):
    return f"{endpoint.mark} ({endpoint.drawing.dwg_id})"


def _format_cambrics_sheet(sheet, endpoint_count):
    title_fill = PatternFill("solid", fgColor="D9EAF7")
    header_fill = PatternFill("solid", fgColor="1F4E79")
    header_font = Font(color="FFFFFF", bold=True)

    for row in range(1, 4):
        sheet.cell(row=row, column=1).font = Font(bold=True)
        sheet.cell(row=row, column=1).fill = title_fill

    header_row = 5
    for cell in sheet[header_row]:
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center")

    widths = {
        "A": 18,
        "B": 24,
        "C": 34,
        "D": 24,
        "E": 14,
        "F": 18,
        "G": 12,
    }
    for column, width in widths.items():
        sheet.column_dimensions[column].width = width

    for row in sheet.iter_rows(min_row=6):
        for cell in row:
            cell.alignment = Alignment(vertical="top", wrap_text=True)

    sheet.freeze_panes = "A6"

    if endpoint_count > 0:
        table_ref = f"A5:G{5 + endpoint_count}"
        table = Table(displayName="CambricsTable", ref=table_ref)
        table.tableStyleInfo = TableStyleInfo(
            name="TableStyleMedium2",
            showFirstColumn=False,
            showLastColumn=False,
            showRowStripes=True,
            showColumnStripes=False,
        )
        sheet.add_table(table)


def _cambrics_filename(project):
    base = slugify(f"cambrics-{project.project_id}-{project.order_number}", allow_unicode=False)
    return f"{base or 'cambrics'}.xlsx"
