{{/* Resource name: the release name, so two releases cannot collide. */}}
{{- define "demo-api.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Labels used to select the pods. These must never change after install. */}}
{{- define "demo-api.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Labels put on every resource. */}}
{{- define "demo-api.labels" -}}
{{ include "demo-api.selectorLabels" . }}
app.kubernetes.io/version: {{ include "demo-api.tag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{/* The image tag that is deployed. */}}
{{- define "demo-api.tag" -}}
{{- .Values.image.tag | default .Chart.AppVersion }}
{{- end }}
