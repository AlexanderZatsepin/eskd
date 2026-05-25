from rest_framework import viewsets

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
    search_fields = ["code", "name"]

    def get_queryset(self):
        queryset = Project.objects.all()
        project_id = self.request.query_params.get("project_id")

        if project_id:
            queryset = queryset.filter(code=project_id)

        return queryset


class CabinetViewSet(viewsets.ModelViewSet):
    serializer_class = CabinetSerializer

    def get_queryset(self):
        queryset = Cabinet.objects.select_related("project")
        project_id = self.request.query_params.get("project_id")
        cabinet_id = self.request.query_params.get("cabinet_id")

        if project_id:
            queryset = queryset.filter(project__code=project_id)
        if cabinet_id:
            queryset = queryset.filter(code=cabinet_id)

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
        cabinet_id = self.request.query_params.get("cabinet_id")
        endpoint_id = self.request.query_params.get("endpoint_id")
        ref_id = self.request.query_params.get("ref_id")
        mark_1 = self.request.query_params.get("mark_1")
        sync_status = self.request.query_params.get("sync_status")

        if project_id:
            queryset = queryset.filter(cabinet__project__code=project_id)
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
