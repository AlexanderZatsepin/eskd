from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from marking.models import Cabinet, Project, WireColor, WireEndpoint, WireType
from marking.serializers import (
    CabinetSerializer,
    ProjectSerializer,
    WireColorSerializer,
    WireEndpointSerializer,
    WireTypeSerializer,
)


class ProjectViewSet(viewsets.ModelViewSet):
    serializer_class = ProjectSerializer
    search_fields = ["code", "project_code", "name"]

    def get_queryset(self):
        queryset = Project.objects.all()
        project_id = self.request.query_params.get("project_id")
        project_code = self.request.query_params.get("project_code")
        active = self.request.query_params.get("active", "true").lower()

        if project_id:
            queryset = queryset.filter(code=project_id)
        if project_code:
            queryset = queryset.filter(project_code=project_code)
        if active not in ("all", "*"):
            queryset = queryset.filter(is_active=active not in ("0", "false", "no"))

        return queryset


class CabinetViewSet(viewsets.ModelViewSet):
    serializer_class = CabinetSerializer

    def get_queryset(self):
        queryset = Cabinet.objects.select_related("project")
        project_id = self.request.query_params.get("project_id")
        project_code = self.request.query_params.get("project_code")
        cabinet_id = self.request.query_params.get("cabinet_id")
        cabinet_code = self.request.query_params.get("cabinet_code")

        if project_id:
            queryset = queryset.filter(project__code=project_id)
        if project_code:
            queryset = queryset.filter(project__project_code=project_code)
        if cabinet_id:
            queryset = queryset.filter(code=cabinet_id)
        if cabinet_code:
            queryset = queryset.filter(cabinet_code=cabinet_code)

        return queryset


class WireTypeViewSet(viewsets.ModelViewSet):
    queryset = WireType.objects.all()
    serializer_class = WireTypeSerializer
    search_fields = ["name"]


class WireColorViewSet(viewsets.ModelViewSet):
    queryset = WireColor.objects.all()
    serializer_class = WireColorSerializer
    search_fields = ["name"]


class WireEndpointViewSet(viewsets.ModelViewSet):
    serializer_class = WireEndpointSerializer
    lookup_field = "uid"

    def get_queryset(self):
        queryset = WireEndpoint.objects.select_related("cabinet", "cabinet__project")
        project_id = self.request.query_params.get("project_id")
        project_code = self.request.query_params.get("project_code")
        cabinet_id = self.request.query_params.get("cabinet_id")
        endpoint_id = self.request.query_params.get("endpoint_id")
        ref_id = self.request.query_params.get("ref_id")
        mark_1 = self.request.query_params.get("mark_1")
        sync_status = self.request.query_params.get("sync_status")

        if project_id:
            queryset = queryset.filter(cabinet__project__code=project_id)
        if project_code:
            queryset = queryset.filter(cabinet__project__project_code=project_code)
        if cabinet_id:
            queryset = queryset.filter(cabinet__code=cabinet_id)
        if endpoint_id:
            queryset = queryset.filter(uid=endpoint_id)
        if ref_id:
            queryset = queryset.filter(ref=ref_id)
        if mark_1:
            queryset = queryset.filter(mark_1=mark_1)
        if sync_status:
            queryset = queryset.filter(sync_status=sync_status)

        return queryset

    @action(detail=False, methods=["post"], url_path="check-drawing")
    def check_drawing(self, request):
        cabinet_id = request.data.get("cabinet_id")
        endpoint_ids = request.data.get("endpoint_ids", [])
        empty_endpoint_handles = request.data.get("empty_endpoint_handles", [])

        if isinstance(endpoint_ids, str):
            endpoint_ids = [item.strip() for item in endpoint_ids.split(",")]
        endpoint_ids = [str(item).strip() for item in endpoint_ids if str(item).strip()]
        if isinstance(empty_endpoint_handles, str):
            empty_endpoint_handles = [item.strip() for item in empty_endpoint_handles.split(",")]
        empty_endpoint_handles = [
            str(item).strip()
            for item in empty_endpoint_handles
            if str(item).strip()
        ]

        cabinet = Cabinet.objects.filter(code=cabinet_id).first()
        if not cabinet:
            return Response(
                {"detail": "Шкаф не найден."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        endpoints = list(
            WireEndpoint.objects.filter(cabinet=cabinet)
            .select_related("cabinet", "wire_type", "wire_color")
            .order_by("mark_1", "mark_2", "uid")
        )
        db_ids = {endpoint.uid for endpoint in endpoints}
        drawing_ids = set(endpoint_ids)

        duplicated_ids = sorted(
            endpoint_id
            for endpoint_id in drawing_ids
            if endpoint_ids.count(endpoint_id) > 1
        )
        blocks_not_in_db = sorted(drawing_ids - db_ids)
        db_not_in_drawing = [
            endpoint
            for endpoint in endpoints
            if endpoint.uid not in drawing_ids
        ]

        report_lines = [
            f"Шкаф: {cabinet.cabinet_code}",
            f"Блоков в чертеже: {len(endpoint_ids)}",
            f"Записей в БД: {len(endpoints)}",
            f"Нет в БД: {len(blocks_not_in_db)}",
            f"Нет в чертеже: {len(db_not_in_drawing)}",
            f"Дубликатов ENDPOINT_ID: {len(duplicated_ids)}",
            f"Блоков без ENDPOINT_ID: {len(empty_endpoint_handles)}",
        ]

        if (
            not blocks_not_in_db
            and not db_not_in_drawing
            and not duplicated_ids
            and not empty_endpoint_handles
        ):
            report_lines.append("Расхождений не найдено.")

        if blocks_not_in_db:
            report_lines.append("--- Блоки есть в чертеже, но нет в БД ---")
            report_lines.extend(blocks_not_in_db)

        if db_not_in_drawing:
            report_lines.append("--- Записи есть в БД, но нет блока в чертеже ---")
            for endpoint in db_not_in_drawing:
                report_lines.append(
                    f"{endpoint.uid}: {endpoint.mark_1} / {endpoint.mark_2}"
                )

        if duplicated_ids:
            report_lines.append("--- Повторяющиеся ENDPOINT_ID в чертеже ---")
            report_lines.extend(duplicated_ids)

        if empty_endpoint_handles:
            report_lines.append("--- Блоки без ENDPOINT_ID в чертеже ---")
            report_lines.extend(f"HANDLE {handle}" for handle in empty_endpoint_handles)

        return Response(
            {
                "cabinet_id": cabinet.code,
                "drawing_count": len(endpoint_ids),
                "db_count": len(endpoints),
                "blocks_not_in_db": blocks_not_in_db,
                "db_not_in_drawing": [
                    {
                        "endpoint_id": endpoint.uid,
                        "mark_1": endpoint.mark_1,
                        "mark_2": endpoint.mark_2,
                    }
                    for endpoint in db_not_in_drawing
                ],
                "duplicated_endpoint_ids": duplicated_ids,
                "empty_endpoint_handles": empty_endpoint_handles,
                "report_lines": report_lines,
                "report_text": "\n".join(report_lines),
            }
        )
