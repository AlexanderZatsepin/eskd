import uuid

from django.db import models


class Project(models.Model):
    code = models.CharField("UUID проекта", max_length=36, blank=True)
    project_code = models.CharField("Шифр проекта", max_length=128, unique=True)
    name = models.CharField("Название проекта", max_length=255)
    created_at = models.DateTimeField("Создано", auto_now_add=True)
    updated_at = models.DateTimeField("Обновлено", auto_now=True)

    class Meta:
        verbose_name = "Проект"
        verbose_name_plural = "Проекты"
        ordering = ["project_code"]
        constraints = [
            models.UniqueConstraint(
                fields=["code"],
                name="unique_project_code",
            )
        ]

    def __str__(self):
        return f"{self.project_code} - {self.name}"

    def save(self, *args, **kwargs):
        if not self.code:
            self.code = self._generate_code()
        super().save(*args, **kwargs)

    @classmethod
    def _generate_code(cls):
        while True:
            code = str(uuid.uuid4())
            if not cls.objects.filter(code=code).exists():
                return code


class Cabinet(models.Model):
    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name="cabinets",
        verbose_name="Проект",
    )
    code = models.CharField("UUID шкафа", max_length=36, blank=True)
    name = models.CharField("Название шкафа", max_length=255, blank=True)
    description = models.CharField("Описание шкафа", max_length=255, blank=True)
    created_at = models.DateTimeField("Создано", auto_now_add=True)
    updated_at = models.DateTimeField("Обновлено", auto_now=True)

    class Meta:
        verbose_name = "Шкаф"
        verbose_name_plural = "Шкафы"
        ordering = ["project__project_code", "code"]
        constraints = [
            models.UniqueConstraint(
                fields=["project", "code"],
                name="unique_cabinet_per_project",
            )
        ]

    def __str__(self):
        return f"{self.project.project_code} / {self.code}"

    def save(self, *args, **kwargs):
        if not self.code:
            self.code = self._generate_code()
        super().save(*args, **kwargs)

    @classmethod
    def _generate_code(cls):
        while True:
            code = str(uuid.uuid4())
            if not cls.objects.filter(code=code).exists():
                return code


class WireType(models.Model):
    name = models.CharField("Тип провода", max_length=64, unique=True)
    description = models.TextField("Описание", blank=True)
    created_at = models.DateTimeField("Создано", auto_now_add=True)
    updated_at = models.DateTimeField("Обновлено", auto_now=True)

    class Meta:
        verbose_name = "Тип провода"
        verbose_name_plural = "Типы проводов"
        ordering = ["name"]

    def __str__(self):
        return self.name


class WireColor(models.Model):
    name = models.CharField("Цвет провода", max_length=32, unique=True)
    description = models.TextField("Описание", blank=True)
    created_at = models.DateTimeField("Создано", auto_now_add=True)
    updated_at = models.DateTimeField("Обновлено", auto_now=True)

    class Meta:
        verbose_name = "Цвет провода"
        verbose_name_plural = "Цвета проводов"
        ordering = ["name"]

    def __str__(self):
        return self.name


class WireEndpoint(models.Model):
    class SyncStatus(models.TextChoices):
        NEW = "NEW", "Новый"
        SYNCED = "SYNCED", "Синхронизирован"
        DIRTY = "DIRTY", "Изменен"
        ERROR = "ERROR", "Ошибка"

    uid = models.CharField("UUID маркировки", max_length=36, primary_key=True, blank=True)
    cabinet = models.ForeignKey(
        Cabinet,
        on_delete=models.CASCADE,
        related_name="wire_endpoints",
        verbose_name="Шкаф",
    )
    ref = models.CharField("UUID связи", max_length=36, blank=True)
    mark_1 = models.CharField("Маркировка 1", max_length=128, default="-", blank=True)
    mark_2 = models.CharField("Маркировка 2", max_length=128, default="-", blank=True)
    wire_type = models.ForeignKey(
        WireType,
        on_delete=models.PROTECT,
        related_name="wire_endpoints",
        null=True,
        blank=True,
        verbose_name="Тип провода",
    )
    wire_color = models.ForeignKey(
        WireColor,
        on_delete=models.PROTECT,
        related_name="wire_endpoints",
        null=True,
        blank=True,
        verbose_name="Цвет провода",
    )
    sync_status = models.CharField(
        "Статус синхронизации",
        max_length=16,
        choices=SyncStatus.choices,
        default=SyncStatus.NEW,
    )
    created_at = models.DateTimeField("Создано", auto_now_add=True)
    updated_at = models.DateTimeField("Обновлено", auto_now=True)

    class Meta:
        verbose_name = "Маркировка"
        verbose_name_plural = "Маркировка"
        ordering = ["cabinet__project__project_code", "cabinet__code", "mark_1", "ref"]
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
