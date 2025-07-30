{{/* Define o nome completo do release (ex: api-comments) */}}
{{- define "api-comments.fullname" -}}
{{- if .Values.fullnameOverride }}
{{ .Values.fullnameOverride }}
{{- else }}
{{- printf "%s" .Release.Name }}
{{- end }}
{{- end }}

{{/* Labels padrão do Helm */}}
{{- define "api-comments.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
