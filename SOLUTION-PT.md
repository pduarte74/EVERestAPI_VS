# Solução de Integração WPMS API - Documentação Técnica

## Visão Geral

Sistema de integração automatizada entre WPMS API e SQL Server para sincronização de dados de produtividade e recursos humanos.

## Arquitectura da Solução

### Componentes Principais

1. **Run-WpmsApiIntegration.ps1** - Script principal de produção
   - Executa chamadas API para múltiplos endpoints
   - Implementa importação dia-a-dia automática para dados de produtividade
   - Grava resultados em tabelas SQL Server
   - Gera logs detalhados de execução

2. **Import-HistoricalData.ps1** - Script de importação histórica
   - Importa dados de intervalos de datas específicos
   - Calcula automaticamente data inicial a partir do último registo na base de dados
   - Suporta modo dry-run para validação
   - Usa operações MERGE para evitar duplicados

3. **Get-AuthToken.ps1** - Módulo de autenticação
   - Gestão de tokens Bearer para API
   - Suporte para credenciais encriptadas

4. **RestClient.ps1** - Cliente HTTP genérico
   - Wrapper para chamadas REST API
   - Tratamento de erros e timeouts
   - Suporte para query parameters complexos

### Estrutura de Directórios

```
EVERestAPI_VS/
├── src/                              # Scripts principais
│   ├── Run-WpmsApiIntegration.ps1    # Script de produção
│   ├── Import-HistoricalData.ps1     # Importação histórica
│   ├── Get-AuthToken.ps1             # Autenticação
│   └── RestClient.ps1                # Cliente REST
├── config/                           # Configurações
│   ├── api-config.psd1               # Configuração principal
│   ├── Setup-SecurePassword.ps1      # Encriptação de password
│   ├── secure-password.txt           # Password encriptada (DPAPI)
│   └── endpoints/                    # Configurações de endpoints
│       ├── TM_USERS.psd1
│       ├── TM_UDT.psd1
│       ├── TM_EQUIPA.psd1
│       └── MOV_ESTAT_PRODUTIVIDADE.psd1
├── logs/                             # Logs de execução
├── tests/                            # Scripts de teste
└── Deploy-ToServer.ps1               # Script de deployment
```

## Funcionalidades Principais

### 1. Importação Dia-a-Dia Automática

O script principal implementa lógica inteligente de importação:

```powershell
# Detecta último registo na base de dados
SELECT MAX([Date]) FROM [dbo].[MOV_ESTAT_PRODUTIVIDADE]

# Inicia importação a partir do dia seguinte
# Itera dia-a-dia até hoje
# Grava cada dia individualmente
```

**Vantagens:**
- Sem duplicados (usa MERGE statements)
- Importação incremental automática
- Continuidade após falhas
- Granularidade diária de dados

### 2. Segurança de Credenciais

Implementa encriptação DPAPI (Data Protection API) do Windows:

```powershell
# Encriptar password
.\config\Setup-SecurePassword.ps1

# Password é encriptada para:
# - Utilizador específico
# - Máquina específica
# Não pode ser desencriptada noutro contexto
```

### 3. Endpoints Configuráveis

Cada endpoint tem configuração própria em ficheiro .psd1:

```powershell
@{
    Name = "Nome do Endpoint"
    Uri = "/Eve/api/WebService/EndpointName"
    Method = "GET"
    Parameters = @{
        DTVL = @{ val1 = "20250101" }
        ENTI = @{ val1 = "('92','93')"; sig1 = "IN" }
    }
    TargetTable = "dbo.TabelaDestino"
    FieldMappings = @{ ... }
    TableSchema = @{ ... }
}
```

### 4. Mapeamento de Tipos de Dados

Conversão automática de tipos API → SQL:

| Tipo SQL | Tipo PowerShell | Tratamento |
|----------|-----------------|------------|
| DATE | DateTime | ParseExact com formato yyyyMMdd |
| DECIMAL(18,3) | Decimal | Conversão com validação |
| INT | Int32 | Conversão com validação |
| NVARCHAR | String | Sem conversão |

### 5. Sistema de Logging

Logs estruturados com níveis:

```
[2025-12-06 12:41:32] [INFO] Starting API calls...
[2025-12-06 12:41:33] [SUCCESS] Status: SUCCESS (HTTP 200)
[2025-12-06 12:41:33] [ERROR] SQL write failed: ...
[2025-12-06 12:41:34] [WARNING] API returned no data
```

**Níveis:** INFO, SUCCESS, WARNING, ERROR

## Endpoints Implementados

### 1. TM_USERS - Utilizadores
- **Endpoint:** I0002read_I0002V03
- **Tabela:** dbo.TM_USERS
- **Descrição:** Lista completa de utilizadores do sistema
- **Campos:** 15 campos incluindo Operator, Name, Profile, Email, etc.

### 2. TM_UDT - Tipos de Trabalho
- **Endpoint:** D0276Dread_all
- **Tabela:** dbo.TM_UDT
- **Descrição:** Tipos de trabalho/tarefas disponíveis
- **Campos:** WrkType, Name, Description, GrpCode

### 3. TM_EQUIPA - Equipas
- **Endpoint:** D0256Dread_all
- **Tabela:** dbo.TM_EQUIPA
- **Descrição:** Estrutura de equipas de trabalho
- **Campos:** Team, Name, Squadra, Director

### 4. MOV_ESTAT_PRODUTIVIDADE - Produtividade
- **Endpoint:** FAPLOGR011showStatsErrors
- **Tabela:** dbo.MOV_ESTAT_PRODUTIVIDADE
- **Descrição:** Estatísticas diárias de produtividade
- **Campos:** 26 campos incluindo quantidades, tempos, distâncias, erros
- **Importação:** Dia-a-dia automática

## Deployment no Servidor

### Pré-requisitos

1. **Windows Server** com PowerShell 5.1+
2. **SQL Server** acessível via Windows Authentication
3. **Conectividade** para wpms.prodout.com
4. **Permissões:**
   - Leitura/escrita no directório de instalação
   - Acesso à base de dados EVEReporting
   - Criação de Scheduled Tasks (opcional)

### Processo de Deployment

```powershell
# 1. Clone ou copie o repositório
git clone https://github.com/pduarte74/EVERestAPI_VS.git

# 2. Execute o script de deployment
.\Deploy-ToServer.ps1 -TargetPath "C:\Apps\WpmsIntegration" -SetupScheduledTask

# 3. Configure a password (no servidor)
cd C:\Apps\WpmsIntegration\config
.\Setup-SecurePassword.ps1

# 4. Verifique a configuração
notepad C:\Apps\WpmsIntegration\config\api-config.psd1

# 5. Teste a execução
cd C:\Apps\WpmsIntegration\src
.\Run-WpmsApiIntegration.ps1 -Verbose
```

### Configuração de Agendamento

A tarefa agendada executa diariamente às 06:00 AM por defeito.

**Modificar horário:**
1. Abra Task Scheduler
2. Localize "WPMS-API-Integration"
3. Propriedades → Triggers → Edit
4. Ajuste horário/frequência

**Executar sob conta de serviço:**
```powershell
# No Task Scheduler:
# General → "Run whether user is logged on or not"
# General → Configurar conta de serviço
# IMPORTANTE: Recriar secure-password.txt com a conta de serviço
```

## Importação de Dados Históricos

### Uso Básico

```powershell
# Importar mês completo
.\Import-HistoricalData.ps1 -StartDate 20250801 -EndDate 20250831

# Importar desde data específica até hoje
.\Import-HistoricalData.ps1 -StartDate 20250101

# Continuar automaticamente do último registo
.\Import-HistoricalData.ps1

# Modo dry-run (sem gravar)
.\Import-HistoricalData.ps1 -StartDate 20250101 -DryRun
```

### Lógica de Data Inicial

Quando `-StartDate` não é fornecido:

1. Consulta: `SELECT MAX([Date]) FROM [dbo].[MOV_ESTAT_PRODUTIVIDADE]`
2. Se existem dados: Inicia do dia seguinte
3. Se tabela vazia: Inicia de hoje

### Re-importação Segura

O script usa `MERGE` statements para operações upsert:

```sql
MERGE INTO [dbo].[MOV_ESTAT_PRODUTIVIDADE] AS target
USING (SELECT ...) AS source
ON target.[Date] = source.[Date] 
   AND target.[Whrs] = source.[Whrs]
   AND target.[Oprt] = source.[Oprt]
   AND target.[WrkType] = source.[WrkType]
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...
```

**Benefícios:**
- Sem erros de chave duplicada
- Actualiza registos existentes
- Insere novos registos
- Operação atómica

## Monitorização e Troubleshooting

### Logs

Localização: `logs\wpms-api-YYYYMMDD-HHMMSS.log`

```powershell
# Ver último log
Get-ChildItem .\logs\*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content

# Procurar erros
Get-Content .\logs\*.log | Select-String "ERROR"

# Verificar sucesso de endpoint específico
Get-Content .\logs\*.log | Select-String "MOV_ESTAT"
```

### Verificação de Dados

```sql
-- Última importação
SELECT MAX([Date]) AS UltimaData, COUNT(*) AS TotalRegistos
FROM [dbo].[MOV_ESTAT_PRODUTIVIDADE]

-- Registos por dia
SELECT [Date], COUNT(*) AS Registos
FROM [dbo].[MOV_ESTAT_PRODUTIVIDADE]
GROUP BY [Date]
ORDER BY [Date] DESC

-- Verificar gaps
WITH DateRange AS (
    SELECT CAST('2025-01-01' AS DATE) AS [Date]
    UNION ALL
    SELECT DATEADD(day, 1, [Date])
    FROM DateRange
    WHERE [Date] < CAST(GETDATE() AS DATE)
)
SELECT dr.[Date]
FROM DateRange dr
LEFT JOIN [dbo].[MOV_ESTAT_PRODUTIVIDADE] m ON dr.[Date] = m.[Date]
WHERE m.[Date] IS NULL
  AND DATEPART(weekday, dr.[Date]) NOT IN (1, 7) -- Excluir fins de semana
OPTION (MAXRECURSION 0)
```

### Erros Comuns

#### 1. Erro de Autenticação
```
ERROR: Authentication failed: The remote server returned an error: (401) Unauthorized
```
**Solução:** Recriar secure-password.txt

#### 2. Erro de Conexão SQL
```
ERROR: SQL connection failed: Cannot open database "EVEReporting"
```
**Solução:** Verificar connection string e permissões

#### 3. API Timeout
```
ERROR: Error retrieving data: The operation has timed out
```
**Solução:** Problema temporário da API, tentar novamente

#### 4. Erro 500 da API
```
ERROR: O servidor remoto devolveu um erro: (500) Erro interno de servidor
```
**Solução:** Problema temporário do WPMS, re-executar mais tarde

## Manutenção

### Rotação de Logs

```powershell
# Manter apenas últimos 30 dias
Get-ChildItem .\logs\*.log | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | 
    Remove-Item
```

### Actualização de Password

```powershell
# Quando a password API mudar:
cd config
.\Setup-SecurePassword.ps1
# Introduzir nova password quando solicitado
```

### Backup de Configuração

```powershell
# Backup de configs (excluir password encriptada)
$backupPath = ".\backup-$(Get-Date -Format 'yyyyMMdd')"
Copy-Item .\config\*.psd1 $backupPath -Recurse
Copy-Item .\config\endpoints\*.psd1 "$backupPath\endpoints"
```

## Performance

### Tempo Médio de Execução

| Endpoint | Registos | Tempo |
|----------|----------|-------|
| TM_USERS | ~400 | 40s |
| TM_UDT | ~170 | 15s |
| TM_EQUIPA | ~40 | 5s |
| MOV_ESTAT (1 dia) | ~50 | 10s |
| MOV_ESTAT (7 dias) | ~350 | 60s |

### Optimizações

1. **Bulk Insert:** Usa SqlBulkCopy para grandes volumes
2. **MERGE Statements:** Operações upsert eficientes
3. **Conexões Reutilizadas:** Uma conexão SQL por execução
4. **Token Caching:** Token válido por 24h

## Segurança

### Credenciais

- ✅ Password encriptada com DPAPI
- ✅ Não versionada no Git (.gitignore)
- ✅ Específica por utilizador/máquina
- ✅ Não transportável entre ambientes

### Logs

- ⚠️ Não contêm passwords
- ⚠️ Contêm dados de negócio (registos API)
- ℹ️ Considerar rotação/limpeza regular

### SQL Injection

- ✅ Usa parametrização de comandos SQL
- ✅ Sem concatenação de strings em queries
- ✅ Validação de tipos de dados

## Contacto e Suporte

**Repositório:** https://github.com/pduarte74/EVERestAPI_VS
**Desenvolvedor:** Pedro Duarte (pedro.duarte@prodout.com)

## Histórico de Versões

### v1.3.0 (2025-12-06)
- ✨ Importação dia-a-dia automática para MOV_ESTAT_PRODUTIVIDADE
- ✨ Cálculo automático de data inicial a partir do último registo
- 🐛 Corrigidos erros de parsing de strings com colons
- 📝 Documentação completa em PT/EN

### v1.2.0 (2025-12-05)
- ✨ Script de importação histórica com MERGE
- 🔄 Operações upsert para evitar duplicados

### v1.1.0 (2025-12-04)
- ✨ Conversão de tipos de dados para MOV_ESTAT_PRODUTIVIDADE
- ✨ Suporte para formato de resposta com chaves numeradas

### v1.0.0 (2025-12-03)
- 🎉 Release inicial
- ✨ 4 endpoints implementados
- 🔐 Encriptação DPAPI de passwords
- 📦 Package de deployment completo
