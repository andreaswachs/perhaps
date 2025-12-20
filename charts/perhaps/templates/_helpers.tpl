{{/*
Expand the name of the chart.
*/}}
{{- define "perhaps.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "perhaps.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "perhaps.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "perhaps.labels" -}}
helm.sh/chart: {{ include "perhaps.chart" . }}
{{ include "perhaps.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "perhaps.selectorLabels" -}}
app.kubernetes.io/name: {{ include "perhaps.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Web selector labels
*/}}
{{- define "perhaps.web.selectorLabels" -}}
{{ include "perhaps.selectorLabels" . }}
app.kubernetes.io/component: web
{{- end }}

{{/*
Worker selector labels
*/}}
{{- define "perhaps.worker.selectorLabels" -}}
{{ include "perhaps.selectorLabels" . }}
app.kubernetes.io/component: worker
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "perhaps.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "perhaps.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the image reference
*/}}
{{- define "perhaps.image" -}}
{{- printf "%s:%s" .Values.global.image.repository (.Values.global.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
Database URL
*/}}
{{- define "perhaps.databaseUrl" -}}
{{- if .Values.database.host }}
{{- printf "postgresql://%s@%s:%d/%s" .Values.database.username .Values.database.host (int .Values.database.port) .Values.database.name }}
{{- end }}
{{- end }}

{{/*
Secret name for database password
*/}}
{{- define "perhaps.databaseSecretName" -}}
{{- if .Values.database.existingSecret }}
{{- .Values.database.existingSecret }}
{{- else }}
{{- include "perhaps.fullname" . }}-db
{{- end }}
{{- end }}

{{/*
Secret name for application secrets
*/}}
{{- define "perhaps.secretName" -}}
{{- if .Values.secrets.existingSecret }}
{{- .Values.secrets.existingSecret }}
{{- else }}
{{- include "perhaps.fullname" . }}
{{- end }}
{{- end }}

{{/*
Default pod anti-affinity for web pods
*/}}
{{- define "perhaps.web.defaultAffinity" -}}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            {{- include "perhaps.web.selectorLabels" . | nindent 12 }}
        topologyKey: kubernetes.io/hostname
{{- end }}

{{/*
Default pod anti-affinity for worker pods
*/}}
{{- define "perhaps.worker.defaultAffinity" -}}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            {{- include "perhaps.worker.selectorLabels" . | nindent 12 }}
        topologyKey: kubernetes.io/hostname
{{- end }}
