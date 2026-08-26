{{/*
Expand the name of the chart.
*/}}
{{- define "openhub.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "openhub.fullname" -}}
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
Headless service name for per-pod bridge DNS.
*/}}
{{- define "openhub.bridgeHeadlessServiceName" -}}
{{- printf "%s-bridge" (include "openhub.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Stable workload resource name. Separate from fullname to allow controller-kind migration without same-name conflicts.
*/}}
{{- define "openhub.workloadName" -}}
{{- printf "%s-workload" (include "openhub.fullname" .) | trunc 52 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "openhub.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openhub.labels" -}}
helm.sh/chart: {{ include "openhub.chart" . }}
{{ include "openhub.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels — IMMUTABLE after first deploy (name + instance ONLY, never version/chart)
*/}}
{{- define "openhub.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openhub.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
StatefulSet workload selector labels. These are distinct from the legacy Deployment traffic lane.
*/}}
{{- define "openhub.workloadSelectorLabels" -}}
{{- include "openhub.selectorLabels" . }}
openhub.soju.dev/traffic: workload
{{- end }}

{{/*
Legacy Deployment traffic selector labels used during controller migration cutover.
*/}}
{{- define "openhub.legacySelectorLabels" -}}
{{- include "openhub.selectorLabels" . }}
openhub.soju.dev/traffic: legacy
{{- end }}

{{/*
ServiceAccount name resolution
*/}}
{{- define "openhub.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "openhub.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Secret name — returns existingSecret or generated name
*/}}
{{- define "openhub.secretName" -}}
{{- if .Values.auth.existingSecret }}
{{- .Values.auth.existingSecret }}
{{- else }}
{{- include "openhub.fullname" . }}
{{- end }}
{{- end }}

{{/*
Database URL secret name — may differ from the app secret when using a dedicated external DB secret.
*/}}
{{- define "openhub.databaseUrlSecretName" -}}
{{- if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret }}
{{- .Values.externalDatabase.existingSecret }}
{{- else }}
{{- include "openhub.secretName" . }}
{{- end }}
{{- end }}

{{/*
Database URL — TWO code paths:
  1. postgresql.enabled: synthesize URL from sub-chart values
  2. external: use externalDatabase.url or synthesize from discrete fields
This is used in secret.yaml to populate the database-url secret key.
*/}}
{{- define "openhub.databaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgresql+asyncpg://%s:%s@%s-postgresql:5432/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password .Release.Name .Values.postgresql.auth.database }}
{{- else if .Values.externalDatabase.url }}
{{- .Values.externalDatabase.url }}
{{- else if and .Values.externalDatabase.host .Values.externalDatabase.user .Values.externalDatabase.database }}
{{- printf "postgresql+asyncpg://%s@%s:%v/%s" .Values.externalDatabase.user .Values.externalDatabase.host (.Values.externalDatabase.port | default 5432) .Values.externalDatabase.database }}
{{- else }}
{{- fail "No database URL source configured. Enable postgresql, set externalDatabase.url, provide externalDatabase.host/user/database, configure externalDatabase.existingSecret, auth.existingSecret, or externalSecrets.enabled." }}
{{- end }}
{{- end }}

{{/*
Migration hook phases — default to pre-install when DB credentials are already available without ExternalSecrets materialization.
*/}}
{{- define "openhub.migrationHookPhases" -}}
{{- if .Values.externalSecrets.enabled -}}
post-install,pre-upgrade
{{- else if .Values.postgresql.enabled -}}
pre-upgrade
{{- else if or .Values.auth.existingSecret .Values.externalDatabase.existingSecret -}}
pre-install,pre-upgrade
{{- else -}}
post-install,pre-upgrade
{{- end -}}
{{- end }}

{{/*
Migration job service account — pre-install hooks cannot rely on chart-created ServiceAccounts.
Use an operator-provided existing SA when explicitly configured; otherwise fall back to default.
*/}}
{{- define "openhub.migrationServiceAccountName" -}}{{- if and .Values.externalSecrets.enabled .Values.serviceAccount.create -}}{{- include "openhub.serviceAccountName" . -}}{{- else if .Values.serviceAccount.name -}}{{- .Values.serviceAccount.name -}}{{- else -}}default{{- end -}}{{- end }}

{{/*
Human-readable install mode label used in NOTES and docs.
*/}}
{{- define "openhub.installMode" -}}
{{- if .Values.postgresql.enabled -}}
bundled
{{- else if .Values.externalSecrets.enabled -}}
external-secrets
{{- else -}}
external-db
{{- end -}}
{{- end }}

{{/*
Image string — resolves registry/repository:tag with optional digest override
*/}}
{{- define "openhub.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.image.registry }}
{{- $repository := .Values.image.repository }}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- if .Values.image.digest }}
{{- printf "%s/%s@%s" $registry $repository .Values.image.digest }}
{{- else }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- end }}
{{- end }}

{{/*
Helm test image string — resolves registry/repository:tag with optional digest override
*/}}
{{- define "openhub.testImage" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.test.image.registry }}
{{- $repository := .Values.test.image.repository }}
{{- if .Values.test.image.digest }}
{{- printf "%s/%s@%s" $registry $repository .Values.test.image.digest }}
{{- else }}
{{- printf "%s/%s:%s" $registry $repository .Values.test.image.tag }}
{{- end }}
{{- end }}

{{/*
Merged nodeSelector: global.nodeSelector + local nodeSelector (local wins).
*/}}
{{- define "openhub.nodeSelector" -}}
{{- $merged := mustMergeOverwrite (deepCopy (.Values.global.nodeSelector | default dict)) (.Values.nodeSelector | default dict) -}}
{{- if $merged }}
{{- toYaml $merged }}
{{- end }}
{{- end -}}

{{/*
Global-only nodeSelector for hooks/tests so app-specific placement does not block installs.
*/}}
{{- define "openhub.globalNodeSelector" -}}
{{- with (.Values.global.nodeSelector | default dict) }}
{{- toYaml . }}
{{- end }}
{{- end -}}
