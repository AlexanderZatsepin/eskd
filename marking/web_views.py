import json
from collections import defaultdict
from io import BytesIO

from django.contrib.auth.decorators import login_required
from django.http import HttpResponse
from django.shortcuts import render
from django.utils.text import slugify
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.table import Table, TableStyleInfo

from marking.models import Cabinet, Project, WireEndpoint


@login_required(login_url="/admin/login/")
def cambrics_report(request):
    projects = list(Project.objects.prefetch_related("cabinets").order_by("code"))
    context = {
        "projects": projects,
        "cabinets_json": json.dumps(_cabinet_map(projects), ensure_ascii=False),
    }

    if request.method == "POST":
        cabinet_pk = request.POST.get("cabinet_id")
        try:
            cabinet = Cabinet.objects.select_related("project").get(pk=cabinet_pk)
        except Cabinet.DoesNotExist:
            context["error"] = "Шкаф не найден."
        else:
            return _build_cambrics_response(cabinet)

    return render(request, "marking/cambrics_report.html", context)


def _cabinet_map(projects):
    result = {}
    for project in projects:
        result[str(project.pk)] = [
            {
                "id": cabinet.pk,
                "code": cabinet.code,
                "name": cabinet.name,
                "description": cabinet.description,
            }
            for cabinet in project.cabinets.all().order_by("code")
        ]
    return result


def _build_cambrics_response(cabinet):
    endpoints = list(
        WireEndpoint.objects.select_related("cabinet", "wire_type", "wire_color")
        .filter(cabinet=cabinet)
        .order_by("mark_1", "ref")
    )

    by_ref_id = defaultdict(list)
    for endpoint in endpoints:
        if endpoint.ref:
            by_ref_id[endpoint.ref].append(endpoint)

    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Кембрики"

    sheet.append(["Проект", cabinet.project.code])
    sheet.append(["Шкаф", cabinet.code])
    sheet.append(["Название", cabinet.name])
    sheet.append([])

    headers = [
        "Маркировка",
        "Куда идет",
        "REF_ID",
        "Тип провода",
        "Цвет",
    ]
    sheet.append(headers)

    for endpoint in endpoints:
        linked = [
            other
            for other in by_ref_id.get(endpoint.ref, [])
            if other.uid != endpoint.uid
        ]
        linked_marks = ", ".join(_endpoint_label(item) for item in linked)

        sheet.append(
            [
                endpoint.mark_1,
                linked_marks,
                endpoint.ref,
                endpoint.wire_type.name if endpoint.wire_type else "-",
                endpoint.wire_color.name if endpoint.wire_color else "-",
            ]
        )

    _format_cambrics_sheet(sheet, len(endpoints))

    output = BytesIO()
    workbook.save(output)
    output.seek(0)

    filename = _cambrics_filename(cabinet)
    response = HttpResponse(
        output.getvalue(),
        content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )
    response["Content-Disposition"] = f'attachment; filename="{filename}"'
    return response


def _endpoint_label(endpoint):
    return f"{endpoint.mark_1} ({endpoint.cabinet.code})"


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
        "A": 24,
        "B": 34,
        "C": 40,
        "D": 18,
        "E": 12,
    }
    for column, width in widths.items():
        sheet.column_dimensions[column].width = width

    for row in sheet.iter_rows(min_row=6):
        for cell in row:
            cell.alignment = Alignment(vertical="top", wrap_text=True)

    sheet.freeze_panes = "A6"

    if endpoint_count > 0:
        table_ref = f"A5:E{5 + endpoint_count}"
        table = Table(displayName="CambricsTable", ref=table_ref)
        table.tableStyleInfo = TableStyleInfo(
            name="TableStyleMedium2",
            showFirstColumn=False,
            showLastColumn=False,
            showRowStripes=True,
            showColumnStripes=False,
        )
        sheet.add_table(table)


def _cambrics_filename(cabinet):
    base = slugify(f"cambrics-{cabinet.project.code}-{cabinet.code}", allow_unicode=False)
    return f"{base or 'cambrics'}.xlsx"
