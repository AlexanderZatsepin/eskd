from rest_framework import serializers

from marking.models import Cabinet, Project, WireColor, WireEndpoint, WireType


class ProjectSerializer(serializers.ModelSerializer):
    project_id = serializers.CharField(source="code", read_only=True)

    class Meta:
        model = Project
        fields = [
            "id",
            "project_id",
            "project_code",
            "name",
            "description",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "project_id", "created_at", "updated_at"]


class CabinetSerializer(serializers.ModelSerializer):
    project_id = serializers.CharField(source="project.code", read_only=True)
    cabinet_id = serializers.CharField(source="code", read_only=True)

    class Meta:
        model = Cabinet
        fields = [
            "id",
            "project",
            "project_id",
            "cabinet_id",
            "name",
            "description",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "project_id", "cabinet_id", "created_at", "updated_at"]


class WireTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = WireType
        fields = ["id", "name", "description", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class WireColorSerializer(serializers.ModelSerializer):
    class Meta:
        model = WireColor
        fields = ["id", "name", "description", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class WireEndpointSerializer(serializers.ModelSerializer):
    endpoint_id = serializers.CharField(source="uid", read_only=True)
    project_id = serializers.CharField(source="cabinet.project.code", read_only=True)
    cabinet_id = serializers.CharField(source="cabinet.code", read_only=True)
    ref_id = serializers.CharField(source="ref", required=False, allow_blank=True)
    wire_type = serializers.CharField(required=False, allow_blank=True)
    wire_color = serializers.CharField(required=False, allow_blank=True)
    sync_status = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = WireEndpoint
        fields = [
            "endpoint_id",
            "cabinet",
            "project_id",
            "cabinet_id",
            "ref_id",
            "mark_1",
            "mark_2",
            "wire_type",
            "wire_color",
            "sync_status",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "endpoint_id",
            "project_id",
            "cabinet_id",
            "created_at",
            "updated_at",
        ]
        extra_kwargs = {
            "ref_id": {"allow_blank": True, "required": False},
            "mark_1": {"allow_blank": True, "required": False},
            "mark_2": {"allow_blank": True, "required": False},
            "sync_status": {"allow_blank": True, "required": False},
        }

    def validate(self, attrs):
        for field in ("mark_1", "mark_2"):
            if not attrs.get(field):
                attrs[field] = "-"
        return attrs

    def validate_sync_status(self, value):
        allowed_values = {choice.value for choice in WireEndpoint.SyncStatus}
        if not value or value not in allowed_values:
            return WireEndpoint.SyncStatus.NEW
        return value

    def create(self, validated_data):
        self._set_dictionary_relations(validated_data)
        return super().create(validated_data)

    def update(self, instance, validated_data):
        self._set_dictionary_relations(validated_data)
        return super().update(instance, validated_data)

    def _set_dictionary_relations(self, validated_data):
        wire_type_name = validated_data.pop("wire_type", None) or "-"
        wire_color_name = validated_data.pop("wire_color", None) or "-"
        validated_data["wire_type"], _ = WireType.objects.get_or_create(name=wire_type_name)
        validated_data["wire_color"], _ = WireColor.objects.get_or_create(name=wire_color_name)
