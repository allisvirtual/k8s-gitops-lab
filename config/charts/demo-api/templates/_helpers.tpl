{{- define "demo-api.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "demo-api.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "demo-api.labels" -}}
{{ include "demo-api.selectorLabels" . }}
app.kubernetes.io/version: {{ include "demo-api.tag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{- define "demo-api.tag" -}}
{{- .Values.image.tag | default .Chart.AppVersion }}
{{- end }}
