from rest_framework import serializers

from marking.models import Drawing, Project, WireEndpoint


class ProjectSerializer(serializers.ModelSerializer):
    class Meta:
        model = Project
        fields = [
            "id",
            "project_id",
            "order_number",
            "name",
            "description",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


class DrawingSerializer(serializers.ModelSerializer):
    project_id = serializers.CharField(source="project.project_id", read_only=True)
    order_number = serializers.CharField(source="project.order_number", read_only=True)

    class Meta:
        model = Drawing
        fields = [
            "id",
            "project",
            "project_id",
            "order_number",
            "dwg_id",
            "name",
            "file_name",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "project_id", "order_number", "created_at", "updated_at"]


class WireEndpointSerializer(serializers.ModelSerializer):
    project_id = serializers.CharField(source="drawing.project.project_id", read_only=True)
    order_number = serializers.CharField(source="drawing.project.order_number", read_only=True)
    dwg_id = serializers.CharField(source="drawing.dwg_id", read_only=True)

    class Meta:
        model = WireEndpoint
        fields = [
            "endpoint_id",
            "drawing",
            "project_id",
            "order_number",
            "dwg_id",
            "ref_id",
            "mark",
            "position",
            "wire_type",
            "wire_color",
            "sync_status",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["project_id", "order_number", "dwg_id", "created_at", "updated_at"]
