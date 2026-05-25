import uuid

from django.db import models


class Project(models.Model):
    code = models.CharField(max_length=64)
    order_number = models.CharField(max_length=64, blank=True)
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["code"]
        constraints = [
            models.UniqueConstraint(
                fields=["code", "order_number"],
                name="unique_project_order_number",
            )
        ]

    def __str__(self):
        return f"{self.code} - {self.name}"


class Cabinet(models.Model):
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="cabinets")
    code = models.CharField(max_length=128)
    name = models.CharField(max_length=255, blank=True)
    description = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["project__code", "code"]
        constraints = [
            models.UniqueConstraint(
                fields=["project", "code"],
                name="unique_cabinet_per_project",
            )
        ]

    def __str__(self):
        return f"{self.project.code} / {self.code}"


class WireType(models.Model):
    name = models.CharField(max_length=64, unique=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class WireColor(models.Model):
    name = models.CharField(max_length=32, unique=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class WireEndpoint(models.Model):
    class SyncStatus(models.TextChoices):
        NEW = "NEW", "New"
        SYNCED = "SYNCED", "Synced"
        DIRTY = "DIRTY", "Dirty"
        ERROR = "ERROR", "Error"

    uid = models.CharField(max_length=36, primary_key=True, blank=True)
    cabinet = models.ForeignKey(Cabinet, on_delete=models.CASCADE, related_name="wire_endpoints")
    ref = models.CharField(max_length=36, blank=True)
    mark_1 = models.CharField(max_length=128, default="-", blank=True)
    mark_2 = models.CharField(max_length=128, default="-", blank=True)
    wire_type = models.ForeignKey(
        WireType,
        on_delete=models.PROTECT,
        related_name="wire_endpoints",
        null=True,
        blank=True,
    )
    wire_color = models.ForeignKey(
        WireColor,
        on_delete=models.PROTECT,
        related_name="wire_endpoints",
        null=True,
        blank=True,
    )
    sync_status = models.CharField(
        max_length=16,
        choices=SyncStatus.choices,
        default=SyncStatus.NEW,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["cabinet__project__code", "cabinet__code", "mark_1", "ref"]
        indexes = [
            models.Index(fields=["ref"]),
            models.Index(fields=["sync_status"]),
        ]

    def __str__(self):
        return f"{self.uid}: {self.mark_1}"

    def save(self, *args, **kwargs):
        if not self.uid:
            self.uid = self._generate_uid()
        super().save(*args, **kwargs)

    @classmethod
    def _generate_uid(cls):
        while True:
            uid = str(uuid.uuid4())
            if not cls.objects.filter(uid=uid).exists():
                return uid
