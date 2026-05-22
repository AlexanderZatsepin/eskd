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
    sync_status = serializers.CharField(required=False, allow_blank=True)

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
        extra_kwargs = {
            "endpoint_id": {
                "allow_blank": True,
                "required": False,
            },
            "ref_id": {"allow_blank": True, "required": False},
            "mark": {"allow_blank": True, "required": False},
            "position": {"allow_blank": True, "required": False},
            "sync_status": {"allow_blank": True, "required": False},
        }

    def validate_sync_status(self, value):
        allowed_values = {choice.value for choice in WireEndpoint.SyncStatus}
        if not value or value not in allowed_values:
            return WireEndpoint.SyncStatus.NEW
        return value
