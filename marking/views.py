from rest_framework import viewsets

from marking.models import Drawing, Project, WireColor, WireEndpoint, WireType
from marking.serializers import (
    DrawingSerializer,
    ProjectSerializer,
    WireColorSerializer,
    WireEndpointSerializer,
    WireTypeSerializer,
)


class ProjectViewSet(viewsets.ModelViewSet):
    serializer_class = ProjectSerializer
    search_fields = ["project_id", "name"]

    def get_queryset(self):
        queryset = Project.objects.all()
        project_id = self.request.query_params.get("project_id")
        order_number = self.request.query_params.get("order_number")

        if project_id:
            queryset = queryset.filter(project_id=project_id)
        if order_number:
            queryset = queryset.filter(order_number=order_number)

        return queryset


class DrawingViewSet(viewsets.ModelViewSet):
    serializer_class = DrawingSerializer

    def get_queryset(self):
        queryset = Drawing.objects.select_related("project")
        project_id = self.request.query_params.get("project_id")
        order_number = self.request.query_params.get("order_number")
        dwg_id = self.request.query_params.get("dwg_id")

        if project_id:
            queryset = queryset.filter(project__project_id=project_id)
        if order_number:
            queryset = queryset.filter(project__order_number=order_number)
        if dwg_id:
            queryset = queryset.filter(dwg_id=dwg_id)

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
    lookup_field = "endpoint_id"

    def get_queryset(self):
        queryset = WireEndpoint.objects.select_related("drawing", "drawing__project")
        project_id = self.request.query_params.get("project_id")
        order_number = self.request.query_params.get("order_number")
        dwg_id = self.request.query_params.get("dwg_id")
        endpoint_id = self.request.query_params.get("endpoint_id")
        ref_id = self.request.query_params.get("ref_id")
        mark_1 = self.request.query_params.get("mark_1")
        sync_status = self.request.query_params.get("sync_status")

        if project_id:
            queryset = queryset.filter(drawing__project__project_id=project_id)
        if order_number:
            queryset = queryset.filter(drawing__project__order_number=order_number)
        if dwg_id:
            queryset = queryset.filter(drawing__dwg_id=dwg_id)
        if endpoint_id:
            queryset = queryset.filter(endpoint_id=endpoint_id)
        if ref_id:
            queryset = queryset.filter(ref_id=ref_id)
        if mark_1:
            queryset = queryset.filter(mark_1=mark_1)
        if sync_status:
            queryset = queryset.filter(sync_status=sync_status)

        return queryset
