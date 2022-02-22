public with sharing class LogPostProcessingService {

	public static final String ERROR_SYSTEM_INFO_LOG_NOT_AVAILABLE = 'Data not yet available. Please check back in a minute or so.';
	public static final String ERROR_SYSTEM_INFO_LOG_RETRIEVE = 'An error occurred retrieving this information, please check the log records for details.';
	public static final String ERROR_SYSTEM_INFO_AUDIT_TRAIL_NOT_SUPPORTED = 'Setup audit trail is not available. Please log a case with salesforce support to turn on "Enable Setup Audit Trail API" permission in the backend.';
	public static final String PAGE_MONITOR_DEPLOYMENT_URL = '/changemgmt/monitorDeployment.apexp';
	public static final String PAGE_MONITOR_DEPLOYMENT_STATUS_DEPLOYMENT = 'Deployment Status';
	public static final String CATEGORY_INTEGRATION = 'Integration';
	public static final String POST_PROCESSING_STATUS_NEEDED = 'Needed';
	public static final String POST_PROCESSING_STATUS_COMPLETED = 'Completed';
	public static final String POST_PROCESSING_STATUS_FAILED = 'Failed';
	public static final String POST_PROCESSING_STATUS_EXECUTED = 'Executed';

	private static final String AUDIT_TRAIL_SOBJECT = 'SetupAuditTrail';
	private static final Set<String> USER_FIELDS = new Set<String> {
		'Id', 'Name'
	};
	public static final Set<String> AUDIT_TRAIL_FIELDS = new Set<String>{
		'Id','Action','CreatedBy.Name','CreatedDate','Display','Section','DelegateUser'
	};
	private static final Set<String> PUBLISHER_FIELDS = new Set<String> {
		'Name', 'NamespacePrefix', 'MajorVersion', 'MinorVersion'
	};
	private static final Set<String> ASYNC_JOB_FIELDS = new Set<String> {
		'Id', 'JobType', 'ApexClassID', 'ApexClass.Name', 'Status', 'MethodName'
	};
	private static final Set<String> DEPLOY_RESULT_FIELDS = new Set<String> {
		'Id', 'Status', 'CompletedDate'
	};

	public static final Integer MAX_ENV_INFO_TIME_WINDOW_HRS = -48;

	public static Connected_Org__c corg;
	public static Set<String> availableNamespaces;

	public class LogPostProcessingQueueable implements Queueable, Database.AllowsCallouts {
		private Id logId;
		public LogPostProcessingQueueable(Id logId) {
			this.logId = logId;
			populateDefaults(this.logId);
		}
		public void execute(QueueableContext context) {
			doLogPostProcessing(this.logId);
		}
	}

	public static List<Object> runQuery(Connected_Org__c corg, String q) {
		return isThisOrg(corg) ? Database.query(q) : HttpUtils.runToolingQuery(corg.Instance_Url__c, ConnectedOrgService.getConnectedOrgAccessToken(corg), q);
	}

	public static void populateDefaults(Id logId) {
		List<Log__c> logs = [
			SELECT
				Id,
				Deploy_Results__c,
				Setup_Audit_Trail__c,
				Pending_Jobs__c,
				Total_Pending_Jobs__c,
				Total_Active_Sessions__c,
				Installed_Packages__c
			FROM Log__c
			WHERE Id = :logId
		];
		if(!logs.isEmpty()) {
			Log__c log = logs[0];
			log.Deploy_Results__c = ERROR_SYSTEM_INFO_LOG_NOT_AVAILABLE;
			log.Setup_Audit_Trail__c = ERROR_SYSTEM_INFO_LOG_NOT_AVAILABLE;
			log.Pending_Jobs__c = ERROR_SYSTEM_INFO_LOG_NOT_AVAILABLE;
			log.Installed_Packages__c = ERROR_SYSTEM_INFO_LOG_NOT_AVAILABLE;
			log.Stacktrace_Parse_Result__c = ERROR_SYSTEM_INFO_LOG_NOT_AVAILABLE;
			update logs;
		}
	}

	public static List<Exception> doLogPostProcessing(Id logId) {
		List<Exception> errors = new List<Exception>();

		List<Log__c> availableLog = [
			SELECT
				Id,
				Deploy_Results__c,
				Setup_Audit_Trail__c,
				Pending_Jobs__c,
				Total_Pending_Jobs__c,
				Total_Active_Sessions__c,
				Installed_Packages__c,
				Organization_Id__c,
				Apex_Name__c,
				Namespace__c,
				User_Id__c,
				Related_Id__c,
				Stacktrace__c,
				Stacktrace_Parse_Result__c,
				Type__c,
				Category__c,
				Flow_Version_Id__c,
				Flow_API_Name__c,
				Flow_Version__c
			FROM Log__c
			WHERE Id = :logId
		];

		if(!availableLog.isEmpty()) {

			Log__c log = availableLog[0];
			corg = ConnectedOrgService.getConnectedOrgById(log.Organization_ID__c);
			if (corg == null) {
				throw new ConnectedOrgService.ConnectedOrgServiceException(ConfigUtil.getConnectedOrgNotSetError(log.Organization_ID__c));
			}

			List<String> methods = new List<String>();
			SObjectDescribeInfo sObjectDescribeInfo;

			try {
				StackTraceParser.corg = corg;
				if (log.Category__c == FlowExceptionParser.PROCESS_BUILDER_CATEGORY) {
					FlowService.ProcessBuilder stackTrace = FlowService.parseProcessBuilderStackTrace(log.Stacktrace__c);
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stacktrace_Parse_Result__c, JSON.serialize(stackTrace));
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stack_trace_parse_result_available__c, stackTrace != null);
				}
				else if (log.Category__c == FlowExceptionParser.FLOW_CATEGORY) {
					FlowService.Flow stackTrace = FlowService.parseFlowStackTrace(log.Stacktrace__c);
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stacktrace_Parse_Result__c, JSON.serialize(stackTrace));
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stack_trace_parse_result_available__c, stackTrace != null);
				}
				else if (log.Category__c == CATEGORY_INTEGRATION) {
					List<StackTraceParser.StackTraceParseResult> stackTrace = StackTraceParser.parseStackTrace(log.Stacktrace__c);
					Map<String, Object> mapStackTraceParseResult = (Map<String, Object>)JSON.deserializeUntyped(log.Stacktrace_Parse_Result__c);
					mapStackTraceParseResult.put('stackTrace', stackTrace);
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stacktrace_Parse_Result__c, JSON.serialize(mapStackTraceParseResult));
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stack_trace_parse_result_available__c,
							stackTrace != null || mapStackTraceParseResult.get('request') != null || mapStackTraceParseResult.get('response') != null);
				}
				else if (log.Type__c.contains(BulkAPIJobBatchService.BULK_API)) {
					List<StackTraceParser.StackTraceParseResult> stackTrace = StackTraceParser.parseStackTrace(log.Stacktrace__c);
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stacktrace_Parse_Result__c, JSON.serialize(stackTrace));
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stack_trace_parse_result_available__c, stackTrace != null);
				}
				else {
					List<StackTraceParser.StackTraceParseResult> stackTrace = StackTraceParser.parseStackTrace(log.Stacktrace__c);
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stacktrace_Parse_Result__c, JSON.serialize(stackTrace));
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stack_trace_parse_result_available__c, (stackTrace != null && !stackTrace.isEmpty()));
				}

			}
			catch(Exception e) {
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stacktrace_Parse_Result__c, ERROR_SYSTEM_INFO_LOG_RETRIEVE);
				errors.add(e);
				methods.add('.parseStackTrace');
			}

			try {
				List<DeployResult> deployments = (List<DeployResult>)truncateItems(MAX_TEXT_AREA_110k_SIZE, getDeployResults());
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Deploy_Results__c, JSON.serialize(deployments));
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Deploy_results_available__c, (deployments != null && !deployments.isEmpty()));
			}
			catch(Exception e) {
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Deploy_Results__c, ERROR_SYSTEM_INFO_LOG_RETRIEVE);
				errors.add(e);
				methods.add('.getDeployResults');
			}
			try {
				String setupAuditTrails = getSetupAuditTrailInfo();
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Setup_Audit_Trail__c, setupAuditTrails);
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Audit_Trail_available__c, String.isNotBlank(setupAuditTrails));
			}
			catch(Exception e) {
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Setup_Audit_Trail__c, ERROR_SYSTEM_INFO_AUDIT_TRAIL_NOT_SUPPORTED);
				errors.add(e);
				methods.add('.getSetupAuditTrailInfo');
			}

			try {
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Pending_Jobs__c, getPendingJobsInfo());
			}
			catch(Exception e) {
				errors.add(e);
				methods.add('.getPendingJobsInfo');
			}

			try {
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Total_Pending_Jobs__c, log.Pending_Jobs__c.split('\n').size());
			}
			catch(Exception e) {
				errors.add(e);
				methods.add('.totalPendingJobs');
			}

			try {
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Total_Active_Sessions__c, getTotalActiveSessions());
			}
			catch(Exception e) {
				errors.add(e);
				methods.add('.getTotalActiveSessions');
			}

			try {
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.User_Name__c, getUserName(log.User_Id__c));
			}
			catch(Exception e) {
				errors.add(e);
				methods.add('.getUserName');
			}

			try {
				sObjectDescribeInfo = getSobjectDescribeInfo(log.Related_Id__c);
				if(sObjectDescribeInfo != null && sObjectDescribeInfo.label != null) {
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Related_Object_Type__c, sObjectDescribeInfo.label);
				}
			}
			catch(Exception e) {
				errors.add(e);
				methods.add('.getSobjectDescribeInfo');
			}

			try {
				if(String.isNotBlank(log.Flow_API_Name__c) && String.isNotBlank(log.Flow_Version__c)) {
					FlowDescribeInfo flowDescribeInfo = getFlowDescribeInfo(log.Flow_API_Name__c, log.Flow_Version__c);
					if(flowDescribeInfo != null && flowDescribeInfo.versionId != null) {
						PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Flow_Version_Id__c, flowDescribeInfo.versionId);
					}
				}
			}
			catch(Exception e) {
				errors.add(e);
				methods.add('.getFlowDescribeInfo');
			}

			try {
				if(sObjectDescribeInfo != null && sObjectDescribeInfo.labelPlural != null){
					PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Area__c, sObjectDescribeInfo.labelPlural);
				}
			}
			catch(Exception e) {
				errors.add(e);
				methods.add('.getAreaSobjectLabelPlural');
			}

			try {
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Installed_Packages__c, getInstalledPackages());
				if(String.isNotBlank(log.Apex_Name__c)) {
					List<String> classNameParts = log.Apex_Name__c.split('\\.');
					if(!classNameParts.isEmpty() && !availableNamespaces.isEmpty() && availableNamespaces.contains(classNameParts[0])) {
						PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Namespace__c, classNameParts[0]);
					}
				}
			}
			catch(Exception e) {
				PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Installed_Packages__c, ERROR_SYSTEM_INFO_LOG_RETRIEVE);
				errors.add(e);
				methods.add('.getInstalledPackages');
			}

			try {
				if(PermissionsUtil.SplunkIntegrationEnabled && ConfigUtil.SPLUNK_SETTINGS.Splunk_Enabled__c) {
					SplunkService.sendLog(log.Id);
				}
			}
			catch(Exception e) {
				errors.add(e);
				methods.add('.SplunkService.sendLog');
			}

			PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Post_Processing_Status__c, LogPostProcessingService.POST_PROCESSING_STATUS_EXECUTED);
			PermissionsUtil.performUpdateDML(new List<Log__c>{log}, Schema.SObjectType.Log__c);

			if (!errors.isEmpty()) {
				Logger.getInstance().internalError(errors, log.Id, true, LogPostProcessingService.class.getName(), methods);
			}
		}
		return errors;
	}

	public static SObjectDescribeInfo getSobjectDescribeInfoFromOrg(Connected_Org__c corg, String relatedRecordId) {
		SObjectDescribeInfo sObjectDescribeInfo;
		if (isThisOrg(corg)) {
			Schema.DescribeSObjectResult describeSObjectResult =  Id.valueOf(relatedRecordId).getSObjectType().getDescribe();
			sObjectDescribeInfo = new SObjectDescribeInfo(describeSObjectResult.getLabel(), describeSObjectResult.getLabelPlural());
		} else {
			String keyPrefix = relatedRecordId.substring(0, 3);
			for (Object sobjectItem : HttpUtils.runToolingQuery(corg.Instance_Url__c, ConnectedOrgService.getConnectedOrgAccessToken(corg), '', ConfigUtil.DESCRIBE_SOBJECT_PATH, ConfigUtil.TOOLING_ITEMS_KEY_SOBJECTS)) {
				Map<String, Object> sobjectMap = (Map<String, Object>)sobjectItem;
				String sobjectKeyPrefix = (String)sobjectMap.get('keyPrefix');
				if (sobjectKeyPrefix == keyPrefix) {
					sObjectDescribeInfo = new SObjectDescribeInfo((String)sobjectMap.get('label'), (String)sobjectMap.get('labelPlural'));
				}
			}
		}
		return sObjectDescribeInfo;
	}

	public static SObjectDescribeInfo getSobjectDescribeInfo(String relatedRecordId) {
		SObjectDescribeInfo sObjectDescribeInfo;
		if (String.isBlank(relatedRecordId)) return sObjectDescribeInfo;
		CacheUtils cacheUtil = new CacheUtils(corg.Name);
		Object cacheObject = cacheUtil.getValue(CacheUtils.KEY_REQUEST_SOBJECT_DESCRIBE);
		if(cacheObject != null) {
			sObjectDescribeInfo = (SObjectDescribeInfo)cacheObject;
		} else {
			sObjectDescribeInfo = getSobjectDescribeInfoFromOrg(corg, relatedRecordId);
			cacheUtil.putValue(CacheUtils.KEY_REQUEST_SOBJECT_DESCRIBE, sObjectDescribeInfo);
		}
		return sObjectDescribeInfo;
	}

	public static FlowDescribeInfo getFlowDescribeInfo(String flowApiName, String flowVersion) {
		FlowDescribeInfo flowDescribeInfo;
		if(String.isBlank(flowApiName) || String.isBlank(flowVersion)) return flowDescribeInfo;

		CacheUtils cacheUtil = new CacheUtils(corg.Name);
		Object cacheObject = cacheUtil.getValue(CacheUtils.KEY_REQUEST_FLOW_DESCRIBE);
		if(cacheObject != null) {
			flowDescribeInfo = (FlowDescribeInfo)cacheObject;
		} else {
			flowDescribeInfo = getFlowDescribeInfoFromOrg(corg, flowApiName, flowVersion);
			cacheUtil.putValue(CacheUtils.KEY_REQUEST_FLOW_DESCRIBE, flowDescribeInfo);
		}
		return flowDescribeInfo;
	}

	public static FlowDescribeInfo getFlowDescribeInfoFromOrg(Connected_Org__c corg, String flowApiName, String flowVersion) {
		FlowDescribeInfo flowDescribeInfo;
		List<String> parts = flowApiName.split('__');
		String flowMasterLabel = (parts.size() == 2) ? parts.get(1) : parts.get(0);
		Integer flowVersionNumber = Integer.valueOf(flowVersion);

		String query = new QBuilder('Flow')
			.selectFields(new Set<String>{'Id', 'DefinitionId'})
			.add(QBuilder.condition('MasterLabel').equalsTo(flowMasterLabel))
			.add(QBuilder.condition('VersionNumber').equalsTo(flowVersionNumber))
			.addLimit(1)
			.build();

		for (Object sobjectItem : HttpUtils.runToolingQuery(corg.Instance_Url__c, ConnectedOrgService.getConnectedOrgAccessToken(corg), query, ConfigUtil.TOOLING_QUERY_API_ENDPOINT)) {
			Map<String, Object> sobjectMap = (Map<String, Object>)sobjectItem;
			flowDescribeInfo = new FlowDescribeInfo((String)sobjectMap.get('Id'), (String)sobjectMap.get('DefinitionId'));
		}
		return flowDescribeInfo;
	}

	public static List<User> getUserNameFromOrg(Connected_Org__c corg, String userId) {
		String query = new QBuilder(User.SObjectType)
		.selectFields(USER_FIELDS)
		.add(QBuilder.condition('Id').equalsTo(userId))
		.addLimit(1)
		.build();
		return (List<User>)JSON.deserialize(JSON.serialize(runQuery(corg, query)), List<User>.class);
	}

	public static String getUserName(String userId) {
		String result = null;
		if (String.isBlank(userId)) return result;
		CacheUtils cacheUtil = new CacheUtils(corg.Name);
		Object cacheObject = cacheUtil.getValue(CacheUtils.KEY_REQUEST_USER_INFO);
		List<User> users = new List<User>();
		if (cacheObject != null) {
			users = (List<User>)cacheObject;
		} else {
			users = getUserNameFromOrg(corg, userId);
			cacheUtil.putValue(CacheUtils.KEY_REQUEST_USER_INFO, users);
		}
		if (users != null && users.size() == 1) {
			return users[0].Name;
		}
		return null;
	}

	public static List<AsyncApexJob> getPendingJobsInfoFromOrg(Connected_Org__c corg) {
		String query = new QBuilder(AsyncApexJob.SObjectType)
		.selectFields(ASYNC_JOB_FIELDS)
		.add(QBuilder.condition('Status').isIn(new String[] {'Processing','Preparing','Queued'}))
		.add(QBuilder.condition('JobType').notEqualsTo('BatchApexWorker'))
		.build();
		return (List<AsyncApexJob>)JSON.deserialize(JSON.serialize(runQuery(corg, query)), List<AsyncApexJob>.class);
	}

	public static String getPendingJobsInfo() {
		List<AsyncApexJob> asyncJobs;
		CacheUtils cacheUtil = new CacheUtils(corg.Name);
		Object cacheObject = cacheUtil.getValue(CacheUtils.KEY_REQUEST_ASYNC_JOBS);

		if(cacheObject != null) {
			asyncJobs = (List<AsyncApexJob>)cacheObject;
		} else {
			asyncJobs = getPendingJobsInfoFromOrg(corg);
			cacheUtil.putValue(CacheUtils.KEY_REQUEST_ASYNC_JOBS, asyncJobs);
		}
		
		List<String> pendingJobsList = new List<String>();
		if(asyncJobs != null) {
			for (AsyncApexJob job : asyncJobs) {
				String apexName = (job.MethodName != null) ? job.MethodName : (job.ApexClass != null && job.ApexClass.Name != null ? job.ApexClass.Name : '');
				String jobItem = job.JobType + ' - ' + job.Status + (String.isNotBlank(apexName) ? (' - ' + apexName) : '');
				if(String.join(pendingJobsList, '\n').length() + jobItem.length() < MAX_TEXT_AREA_28k_SIZE){
					pendingJobsList.add(jobItem);
				}
				else {
					pendingJobsList.add('...');
					pendingJobsList.add('Total: ' + asyncJobs.size());
					break;
				}
			}
		}
		return String.join(pendingJobsList, '\n');
	}

	public static List<Publisher> getInstalledPackagesFromOrg(Connected_Org__c corg) {
		String query = new QBuilder(Publisher.SObjectType)
		.selectFields(PUBLISHER_FIELDS)
		.add(QBuilder.condition('IsSalesforce').equalsTo(false))
		.build();
		return (List<Publisher>)JSON.deserialize(JSON.serialize(runQuery(corg, query)), List<Publisher>.class);
	}

	public static String getInstalledPackages() {
		List<Publisher> publishers;
		availableNamespaces = new Set<String>();
		CacheUtils cacheUtil = new CacheUtils(corg.Name);
		Object cacheObject = cacheUtil.getValue(CacheUtils.KEY_REQUEST_PACKAGES_INFO);

		if(cacheObject != null) {
			publishers = (List<Publisher>)cacheObject;
		} else {
			publishers = getInstalledPackagesFromOrg(corg);
			cacheUtil.putValue(CacheUtils.KEY_REQUEST_PACKAGES_INFO, publishers);
		}
		
		List<String> lines = new List<String>();
		if(publishers != null) {
			for (Publisher p : publishers) {
				String pNamespacePrefix = p.NamespacePrefix != null ? p.NamespacePrefix : 'unmanaged package';
				lines.add(pNamespacePrefix + ' (' + p.MajorVersion + '.' + p.MinorVersion + ')');
				availableNamespaces.add(p.NamespacePrefix);
			}
		}
		return String.join(lines, '\n');
	}

	public static Decimal getTotalActiveSessionsFromOrg(Connected_Org__c corg) {
		String query = new QBuilder(AuthSession.SObjectType)
		.selectFields(new Set<String> {'COUNT_DISTINCT(LoginHistory.UserId) number'})
		.build();
		List<Object> results = runQuery(corg, query);
		if (results != null && results.size() == 1) {
			if (isThisOrg(corg)) {
				AggregateResult result = (AggregateResult)results[0];
				return (Decimal)result.get('number');
			} else {
				Map<String, Object> resultMap = (Map<String, Object>)results[0];
				return (Decimal)resultMap.get('number');
			}
		}
		return null;
	}

	public static Decimal getTotalActiveSessions() {
		Decimal result = null;
		CacheUtils cacheUtil = new CacheUtils(corg.Name);
		Object cacheObject = cacheUtil.getValue(CacheUtils.KEY_REQUEST_AUTH_SESSIONS);

		if(cacheObject != null) {
			result = (Decimal)cacheObject;
		} else {
			result = getTotalActiveSessionsFromOrg(corg);
			cacheUtil.putValue(CacheUtils.KEY_REQUEST_AUTH_SESSIONS, result);
		}
		return result;
	}

	public static String getSetupAuditTrailInfo() {
		String result;
		CacheUtils cacheUtil = new CacheUtils(corg.Name);
		Object cacheObject = cacheUtil.getValue(CacheUtils.KEY_REQUEST_AUDIT_TRAIL);

		if(cacheObject != null) {
			result = (String)cacheObject;
		} else {
			result = getAuditTrailFromOrg(corg);
			cacheUtil.putValue(CacheUtils.KEY_REQUEST_AUDIT_TRAIL, result);
		}

		return result;
	}

	public static Boolean isThisOrg(Connected_Org__c corg) {
		return UserInfo.getOrganizationId() == Id.valueOf(corg.Name);
	}

	public static String getAuditTrailFromOrg(Connected_Org__c corg) {
		String query = new QBuilder(AUDIT_TRAIL_SOBJECT)
		.selectFields(AUDIT_TRAIL_FIELDS)
		.add(QBuilder.condition('CreatedDate').isGreaterThan(Datetime.now().addHours(MAX_ENV_INFO_TIME_WINDOW_HRS)))
		.add(QBuilder.orderBy('CreatedDate').descending())
		.addLimit(100)
		.build();

		List<Object> items = runQuery(corg, query);
		return JSON.serialize(truncateItems(MAX_TEXT_AREA_110k_SIZE, items));
	}

	// 90% of LTA 132k Max Size
	public static final Integer MAX_TEXT_AREA_110k_SIZE = 110000;
	// 90% of LTA 32k Max Size
	public static final Integer MAX_TEXT_AREA_28k_SIZE = 28000;
	public static List<Object> truncateItems(Integer maxSize, List<Object> items) {
		List<Object> result = new List<Object>();
		if(items != null) {
			for(Object o : items) {
				if(JSON.serialize(result).length() + JSON.serialize(o).length() < maxSize){
					result.add(o);
				}
				else break;
			}
		}
		return result;
	}

	public static List<DeployResult> truncateItems(Integer maxSize, List<DeployResult> items) {
		List<DeployResult> result = new List<DeployResult>();
		if(items != null) {
			for(DeployResult o : items) {
				if(JSON.serialize(result).length() + JSON.serialize(o).length() < maxSize){
					result.add(o);
				}
				else break;
			}
		}
		return result;
	}

	public static List<DeployResult> getDeployResultsFromOrg() {
		String query = new QBuilder('deployRequest')
			.selectFields(DEPLOY_RESULT_FIELDS)
			.add(QBuilder.condition('Status').isIn(new List<String>{'Succeeded', 'SucceededPartial'}))
			.addLimit(10)
			.add(new QOrder('CompletedDate').descending())
			.build();
		List<DeployResult> lstDeployResults = new List<DeployResult>();
		for (Object recordSObject : HttpUtils.runToolingQuery(corg.Instance_Url__c, ConnectedOrgService.getConnectedOrgAccessToken(corg), query, ConfigUtil.TOOLING_QUERY_API_51_ENDPOINT)) {
			DeployResult record = (DeployResult)JSON.deserialize(JSON.serialize(recordSObject), DeployResult.class);
			DeployResult deployResult = new DeployResult();
			deployResult.id = record.id;
			deployResult.status = String.valueOf(record.status);
			deployResult.completedDate = record.completedDate;
			lstDeployResults.add(deployResult);
		}
		return lstDeployResults;
	}

	public static List<DeployResult> getDeployResults() {
		List<DeployResult> result = null;
		CacheUtils cacheUtil = new CacheUtils(corg.Name);
		Object cacheObject = cacheUtil.getValue(CacheUtils.KEY_REQUEST_DEPLOYMENT_JOBS);
		if (cacheObject != null) {
			result = (List<DeployResult>)cacheObject;
		} else {
			result = getDeployResultsFromOrg();
			cacheUtil.putValue(CacheUtils.KEY_REQUEST_DEPLOYMENT_JOBS, result);
		}
		return result;
	}

	public class DeployRequestResponse {
		public List<Metadata.DeployResult> records;
	}

	public class DeployResult {
		public String id;
		public String status;
		public Integer numberComponentsTotal;
		public Integer numberComponentsDeployed;
		public Integer numberComponentErrors;
		public Datetime startDate;
		public Boolean runTestsEnabled;
		public String createdBy;
		public String createdByName;
		public Datetime completedDate;
	}

	public class SObjectDescribeInfo {
		public String label;
		public String labelPlural;

		public SObjectDescribeInfo(String label, String labelPlural) {
			this.label = label;
			this.labelPlural = labelPlural;
		}
	}

	public class FlowDescribeInfo {
		public String versionId;
		public String definitionId;

		public FlowDescribeInfo(String versionId, String definitionId) {
			this.versionId = versionId;
			this.definitionId = definitionId;
		}
	}

	public class AsyncApexJobWrapper {
		public String JobType;
		public String Status;
		public ApexClassWrapper ApexClass;
	}

	public class ApexClassWrapper {
		public String Name;
	}

	public class LogPostProcessingServiceException extends Exception {}

}