public without sharing class PermissionsUtil {

	public static final Integer DEFAULT_FEATURE_LIMIT = 100;
	public static final Boolean DO_PERMISSION_CHECKS = false;

	public static List<Database.SaveResult> performUpdateDML(List<SObject> sObjectList) {
		List<Database.SaveResult> saveResults;
		if(!sObjectList.isEmpty()) {
			Schema.DescribeSObjectResult dsr = sObjectList.get(0).getSObjectType().getDescribe();
			if(!DO_PERMISSION_CHECKS || (dsr.isAccessible() && dsr.isUpdateable())) {
				saveResults = Database.update(sObjectList, false);
			}
		}
		return saveResults;
	}

	public static List<Database.SaveResult> performUpdateDML(List<SObject> sObjectList, Schema.DescribeSObjectResult dsr) {
		List<Database.SaveResult> saveResults;
		if(!sObjectList.isEmpty()) {
			if(!DO_PERMISSION_CHECKS || (dsr.isAccessible() && dsr.isUpdateable())) {
				saveResults = Database.update(sObjectList, false);
			}
		}
		return saveResults;
	}

	public static List<Database.DeleteResult> performDeleteDML(List<SObject> sObjectList, Schema.DescribeSObjectResult dsr) {
		List<Database.DeleteResult> deleteResults;
		if(!sObjectList.isEmpty()) {
			if(!DO_PERMISSION_CHECKS || (dsr.isAccessible() && dsr.isDeletable())) {
				deleteResults = Database.delete(sObjectList, false);
			}
		}
		return deleteResults;
	}

	public static List<Database.DeleteResult> performDeleteDML(List<Id> listIds, Schema.DescribeSObjectResult dsr) {
		List<Database.DeleteResult> deleteResults;
		if(!listIds.isEmpty()) {
			if(!DO_PERMISSION_CHECKS || (dsr.isAccessible() && dsr.isDeletable())) {
				deleteResults = Database.delete(listIds, false);
			}
		}
		return deleteResults;
	}

	public static List<Database.SaveResult> performInsertImmediateDML(List<SObject> sObjectList, Schema.DescribeSObjectResult dsr) {
		List<Database.SaveResult> saveResults;
		if(!sObjectList.isEmpty()) {
			if(!DO_PERMISSION_CHECKS || (dsr.isAccessible() && dsr.isCreateable())) {
				saveResults = Database.insertImmediate(sObjectList);
			}
		}
		return saveResults;
	}

	public static List<Database.UpsertResult> performUpsertDML(List<SObject> sObjectList, Schema.DescribeSObjectResult dsr, SObjectField field) {
		List<Database.UpsertResult> upsertResults;
		if(!sObjectList.isEmpty()) {
			if(!DO_PERMISSION_CHECKS || (dsr.isAccessible() && dsr.isCreateable() && dsr.isUpdateable())) {
				upsertResults = Database.upsert(sObjectList, field);
			}
		}
		return upsertResults;
	}

	public static List<Database.UpsertResult> performUpsertDML(List<SObject> sObjectList, Schema.DescribeSObjectResult dsr) {
		List<Database.UpsertResult> upsertResults;
		if(!sObjectList.isEmpty()) {
			if(!DO_PERMISSION_CHECKS || (dsr.isAccessible() && dsr.isCreateable() && dsr.isUpdateable())) {
				upsertResults = Database.upsert(sObjectList);
			}
		}
		return upsertResults;
	}

	public static List<Database.SaveResult> performInsertDML(List<SObject> sObjectList, Schema.DescribeSObjectResult dsr) {
		List<Database.SaveResult> saveResults;
		if(!sObjectList.isEmpty()) {
			if(!DO_PERMISSION_CHECKS || (dsr.isAccessible() && dsr.isCreateable())) {
				saveResults = Database.insert(sObjectList, false);
			}
		}
		return saveResults;
	}

	public static List<Database.SaveResult> performInsertDML(List<SObject> sObjectList) {
		List<Database.SaveResult> saveResults;
		if(!sObjectList.isEmpty()) {
			Schema.DescribeSObjectResult dsr = sObjectList.get(0).getSObjectType().getDescribe();
			if(!DO_PERMISSION_CHECKS || (dsr.isAccessible() && dsr.isCreateable())) {
				saveResults = Database.insert(sObjectList, false);
			}
		}
		return saveResults;
	}

	public static void publishLogEvent(List<Log__c> logs) {
		Log_Event__e logEvent = (Log_Event__e)PermissionsUtil.newSObject(Schema.sObjectType.Log_Event__e);
		PermissionsUtil.putSObjectField(logEvent, Schema.sObjectType.Log_Event__e.fields.Body__c, JSON.serialize(logs));
		EventBus.publish(
			logEvent
		);
	}

	public static SObject newSObject(Schema.DescribeSObjectResult dsr) {
		SObject sObj;
		if(!DO_PERMISSION_CHECKS || dsr.isCreateable()) {
			sObj = dsr.getSobjectType().newSObject();
		}
		return sObj;
	}

	public static void putSObjectField(SObject sObj, Schema.DescribeFieldResult dfr, Object value) {
		if(!DO_PERMISSION_CHECKS || (dfr.isCreateable() && dfr.isUpdateable())) {
			sObj.put(dfr.getName(), value);
		}
	}

	public static void putSObjectFields(List<SObject> sObjList, Schema.DescribeFieldResult dfr, Object value, Boolean isOverride) {
		if(!DO_PERMISSION_CHECKS || (dfr.isCreateable() && dfr.isUpdateable())) {
			for(SObject sObj : sObjList) {
				if(isOverride) {
					sObj.put(dfr.getName(), value);
				}
				else if(sObj.get(dfr.getName()) == null) {
					sObj.put(dfr.getName(), value);
				}
			}
		}
	}

	public static void putSObjectField(SObject sObj, String objectFieldName, Object value) {
		Schema.DescribeSObjectResult dsr = sObj.getSobjectType().getDescribe();
		Map<String, Schema.SObjectField> fieldsMap = dsr.fields.getMap();
		SObjectField sObjectField = fieldsMap.get(objectFieldName);
		if(sObjectField != null) {
			DescribeFieldResult dfr = sObjectField.getDescribe();
			if(dfr != null) {
				putSObjectField(sObj, dfr, value);
			}
		}
	}

	public static Boolean getPackageFeatureBoolean(String featureName) {
		Boolean result = false;
		try {
			result = FeatureManagement.checkPackageBooleanValue(featureName);
		}
		// catch devorg case
		catch(System.NoDataFoundException e) {
			result = true;
		}
		return result;
	}

	public static Integer getPackageFeatureInteger(String featureName) {
		return getPackageFeatureInteger(featureName, DEFAULT_FEATURE_LIMIT);
	}

	public static Integer getPackageFeatureInteger(String featureName, Integer defaultValue) {
		Integer result = defaultValue;
		try {
			result = FeatureManagement.checkPackageIntegerValue(featureName);
		}
		// catch devorg case
		catch(System.NoDataFoundException e) {
			result = defaultValue;
		}
		return result;
	}

	public static void setPackageFeatureInteger(String apiName, Integer intValue) {
		try {
			FeatureManagement.setPackageIntegerValue(apiName, intValue);
		}
		catch(Exception e){}
	}

	public static void setMetricsValue(Integer intValue) {
		setPackageFeatureInteger(FEATURE_PARAM_MAP_5_NAME, intValue);
	}

	public static final String FP_JIRA_INTEGRATION_ENABLED = 'JiraIntegrationEnabled';
	public static final String FP_SLACK_INTEGRATION_ENABLED = 'SlackIntegrationEnabled';
	public static final String FP_PAGER_DUTY_INTEGRATION_ENABLED = 'PagerDutyIntegrationEnabled';
	public static final String FP_SPLUNK_INTEGRATION_ENABLED = 'SplunkIntegrationEnabled';
	public static final String FP_MONITORING_ENABLED = 'MonitoringEnabled';
	public static final String FP_ARCHIVAL_ENABLED = 'ArchivalEnabled';
	public static final String FP_SENSITIVE_DATA_MASK_ENABLED = 'SensitiveDataMaskingEnabled';
	public static final String FP_FLOW_DEBUG_VIEW_ENABLED = 'FlowDebugViewEnabled';
	public static final String FP_NOTIFICATION_INTEGRATION_ENABLED = 'NotificationIntegrationEnabled';
	public static final String FP_BULK_API_TRACKING_ENABLED = 'BulkAPITrackingEnabled';
	public static final String FP_INTEGRATION_DEBUG_VIEW_ENABLED = 'IntegrationDebugViewEnabled';
	public static final String FP_NOTIFICATIONS_FOR_PHAROS_ERRORS = 'NotificationsForPharosErrors';
	public static final String FP_TEAMS_INTEGRATION_ENABLED = 'TeamsIntegrationEnabled';
	public static final String FP_GITHUB_INTEGRATION_ENABLED = 'GitHubIntegrationEnabled';
	public static final String FP_CHANGE_TRACKING_ENABLED = 'ChangeTrackingEnabled';

	public static final String FP_CHARGIFY_PRODUCT_EDITION = 'Edition';
	public static final String CHARGIFY_PRODUCT_EDITION_ENTERPRISE = 'Enterprise';
	public static final String CHARGIFY_PRODUCT_EDITION_PROFESSIONAL = 'Professional';
	public static final String CHARGIFY_PRODUCT_EDITION_BASIC = 'Basic';
	public static final String CHARGIFY_PRODUCT_EDITION_ADMIN = 'Admin';

	// 2bit per Chargify Product Edition value
	public static final Map<Integer, String> CHARGIFY_PRODUCT_EDITION_MAP = new Map<Integer, String>{
		0 => CHARGIFY_PRODUCT_EDITION_ENTERPRISE,
		1 => CHARGIFY_PRODUCT_EDITION_PROFESSIONAL,
		2 => CHARGIFY_PRODUCT_EDITION_BASIC,
		3 => CHARGIFY_PRODUCT_EDITION_ADMIN
	};

	// 10 * 1bit, 11-12 bits, 13-15 * 1bit = 16bit of 29bit
	public static final Map<String, Integer> MAP_FEATURE1_INDEX_BY_NAME = new Map<String, Integer> {
		FP_MONITORING_ENABLED => 0,
		FP_ARCHIVAL_ENABLED => 1,
		FP_JIRA_INTEGRATION_ENABLED => 2,
		FP_SLACK_INTEGRATION_ENABLED => 3,
		FP_SPLUNK_INTEGRATION_ENABLED => 4,
		FP_PAGER_DUTY_INTEGRATION_ENABLED => 5,
		FP_SENSITIVE_DATA_MASK_ENABLED => 6,
		FP_FLOW_DEBUG_VIEW_ENABLED => 7,
		FP_NOTIFICATION_INTEGRATION_ENABLED => 8,
		FP_BULK_API_TRACKING_ENABLED => 9,
		FP_CHARGIFY_PRODUCT_EDITION => 10,
		FP_INTEGRATION_DEBUG_VIEW_ENABLED => 12,
		FP_NOTIFICATIONS_FOR_PHAROS_ERRORS => 13,
		FP_TEAMS_INTEGRATION_ENABLED => 14,
		FP_GITHUB_INTEGRATION_ENABLED => 15,
		FP_CHANGE_TRACKING_ENABLED => 16
	};

	public static Map<Integer, Boolean> FeatureMap1 {
		get {
			if(FeatureMap1 == null) {
				FeatureMap1 = new Map<Integer, Boolean>();
				Map<Integer, Integer> bitmap = getBitmapFromInteger(FeatureMap1IntValue);
				for(Integer i : bitmap.keySet()) {
					FeatureMap1.put(i, bitmap.get(i) == 1);
				}
			}
			return FeatureMap1;
		}
		private set;
	}

	public static final String FP_MAX_MONITORING_RULES = 'MaxMonitoringRules';
	public static final String FP_MAX_ARCHIVAL_RULES = 'MaxArchivalRules';
	public static final String FP_MAX_CONNECTED_ORGS = 'MaxConnectedOrgs';
	public static final String FP_MAX_JIRA_RULES = 'MaxJiraRules';

	// 3 x 8bits = 24bit of 29bit
	public static final Map<String, Integer> MAP_FEATURE2_INDEX_BY_NAME = new Map<String, Integer> {
		FP_MAX_MONITORING_RULES => 0,
		FP_MAX_ARCHIVAL_RULES => 1,
		FP_MAX_CONNECTED_ORGS => 2
	};

	//{"2":255,"1":255,"0":255}
	public static Map<Integer, Integer> FeatureMap2 {
		get {
			if(FeatureMap2 == null) {
				FeatureMap2 = new Map<Integer, Integer>();
				split29bitsBy8bits(FeatureMap2IntValue, FeatureMap2);
			}
			return FeatureMap2;
		}
		private set;
	}

	public static final String FP_MAX_NOTIFICATION_RULES = 'MaxNotificationRules';
	// 2 x 8bits = 16bit of 29bit
	public static final Map<String, Integer> MAP_FEATURE3_INDEX_BY_NAME = new Map<String, Integer> {
		FP_MAX_NOTIFICATION_RULES => 0,
		FP_MAX_JIRA_RULES => 1
	};

	//{"2":255,"1":255,"0":255}
	public static Map<Integer, Integer> FeatureMap3 {
		get {
			if(FeatureMap3 == null) {
				FeatureMap3 = new Map<Integer, Integer>();
				split29bitsBy8bits(FeatureMap3IntValue, FeatureMap3);
			}
			return FeatureMap3;
		}
		private set;
	}

	public static final String FP_REQUEST_ASYNC_JOBS_TTL = 'RequestAsyncJobsTTL';
	public static final String FP_REQUEST_AUDIT_TRAIL_TTL = 'RequestAuditTrailTTL';
	public static final String FP_REQUEST_AUTH_SESSION_TTL = 'RequestAuthSessionTTL';
	public static final String FP_REQUEST_DEPLOYMENT_JOBS_TTL = 'RequestDeploymentJobsTTL';
	public static final String FP_REQUEST_PACKAGES_INFO_TTL = 'RequestPackagesInfoTTL';
	public static final String FP_REQUEST_SOBJECT_DESCRIBE_TTL = 'RequestSobjectDescribeTTL';
	public static final String FP_REQUEST_STACK_TRACE_TTL = 'RequestStackTraceTTL';
	public static final String FP_REQUEST_USER_INFO_TTL = 'RequestUserInfoTTL';
	public static final String FP_REQUEST_ENCRYPTED_TOKEN_TTL = 'RequestEncryptedTokenTTL';

	// 9 * 3bit = 27bit of 29bit
	public static final Map<String, Integer> MAP_FEATURE4_INDEX_BY_NAME = new Map<String, Integer> {
		FP_REQUEST_ASYNC_JOBS_TTL => 0,
		FP_REQUEST_AUDIT_TRAIL_TTL => 1,
		FP_REQUEST_AUTH_SESSION_TTL => 2,
		FP_REQUEST_DEPLOYMENT_JOBS_TTL => 3,
		FP_REQUEST_PACKAGES_INFO_TTL => 4,
		FP_REQUEST_SOBJECT_DESCRIBE_TTL => 5,
		FP_REQUEST_STACK_TRACE_TTL => 6,
		FP_REQUEST_USER_INFO_TTL => 7,
		FP_REQUEST_ENCRYPTED_TOKEN_TTL => 8
	};

	// 3bit per TTL value
	public static final Map<Integer, Integer> TTL_MAP = new Map<Integer, Integer>{
		0 => 0,       // off
		1 => 5*60,    // 5 min
		2 => 10*60,   // 10 min
		3 => 30*60,   // 30 min
		4 => 60*60,   // 1h
		5 => 120*60,  // 2h
		6 => 240*60,  // 4h
		7 => 600*60   // 10h
	};

	public static Map<Integer, Integer> FeatureMap4 {
		get {
			if(FeatureMap4 == null) {
				FeatureMap4 = new Map<Integer, Integer>();
				split29bitsBy3Bits(FeatureMap4IntValue, FeatureMap4);
			}
			return FeatureMap4;
		}
		private set;
	}

	public static void split29bitsBy3Bits(Integer intValue, Map<Integer, Integer> result) {
		Map<Integer, Integer> bitmap = getBitmapFromInteger(intValue);
		for(Integer i = 0, j = 0; i < 9; i++) {
			Integer byteInteger = getIntegerFromBitmap(new Map<Integer, Integer>{
					0 => bitmap.get(j),
					1 => bitmap.get(j+1),
					2 => bitmap.get(j+2)
			});
			j+=3;
			result.put(i, byteInteger);
		}
	}

	public static void split29bitsBy8bits(Integer intValue, Map<Integer, Integer> result) {
		Map<Integer, Integer> bitmap = getBitmapFromInteger(intValue);
		for(Integer i = 0, j = 0; i < 3; i++) {
			Integer byteInteger = getIntegerFromBitmap(new Map<Integer, Integer>{
					0 => bitmap.get(j),
					1 => bitmap.get(j+1),
					2 => bitmap.get(j+2),
					3 => bitmap.get(j+3),
					4 => bitmap.get(j+4),
					5 => bitmap.get(j+5),
					6 => bitmap.get(j+6),
					7 => bitmap.get(j+7)
			});
			j+=8;
			result.put(i, byteInteger);
		}
	}
	// 10 * 1bit, 11-12 bits, 13 * 1bit = 13bit of 29bit
	public static final Map<Integer, Integer> DEFAULT_FEATURE_MAP_1_VALUE_MAP = new Map<Integer, Integer>{
			0=>1, 1=>1,	2=>1,
			3=>1, 4=>1,	5=>1,
			6=>1, 7=>1,	8=>1,
			9=>1, 10=>0, 11=>0,
			12=>1, 13=>0, 14=>0,
			15=>0, 16=>0, 17=>0,
			18=>0, 19=>0, 20=>0,
			21=>0, 22=>0, 23=>0,
			24=>0, 25=>0, 26=>0,
			27=>0, 28=>0
	};
	// all TTL params 0 except FP_REQUEST_ENCRYPTED_TOKEN_TTL (2 hours)
	public static final Map<Integer, Integer> DEFAULT_FEATURE_MAP_4_VALUE_MAP = new Map<Integer, Integer>{
			0=>0, 1=>0,	2=>0,
			3=>0, 4=>0,	5=>0,
			6=>0, 7=>0,	8=>0,
			9=>0, 10=>0, 11=>0,
			12=>0, 13=>0, 14=>0,
			15=>0, 16=>0, 17=>0,
			18=>0, 19=>0, 20=>0,
			21=>0, 22=>0, 23=>0,
			24=>1, 25=>0, 26=>1,
			27=>0, 28=>0
	};
	// all boolean params (up to 29 param)
	public static final String FEATURE_PARAM_MAP_1_NAME = 'FeatureMap1';
	// all max count params (3 params per 8bit, 255 max)
	public static final String FEATURE_PARAM_MAP_2_NAME = 'MaxMonitoringRules';
	// all max count params (3 params per 8bit, 255 max)
	public static final String FEATURE_PARAM_MAP_3_NAME = 'MaxArchivalRules';
	// all TTL params (9 params per 3bit, 0-8 values)
	public static final String FEATURE_PARAM_MAP_4_NAME = 'RequestAsyncJobsTTL';
	// Subscriber to LMA
	public static final String FEATURE_PARAM_MAP_5_NAME = 'Metrics';
	public static final String FEATURE_PARAM_MAP_6_NAME = 'Metrics2';

	public static final Integer DEFAULT_FEATURE_MAP_1_VALUE = PermissionsUtil.getIntegerFromBitmap(DEFAULT_FEATURE_MAP_1_VALUE_MAP);
	public static final Integer DEFAULT_FEATURE_MAP_2_VALUE = Integer.valueOf(Math.pow(2, 24) - 1);
	public static final Integer DEFAULT_FEATURE_MAP_3_VALUE = Integer.valueOf(Math.pow(2, 24) - 1);
	public static final Integer DEFAULT_FEATURE_MAP_4_VALUE = PermissionsUtil.getIntegerFromBitmap(DEFAULT_FEATURE_MAP_4_VALUE_MAP);
	public static final Integer DEFAULT_FEATURE_MAP_5_VALUE = 0;
	public static final Integer DEFAULT_FEATURE_MAP_6_VALUE = 0;
	public static final Integer MAX_USED_BITS_IN_INTEGER = 29;

	@TestVisible
	public static Integer FeatureMap1IntValue {
		get {
			if(FeatureMap1IntValue == null) {
				FeatureMap1IntValue = getPackageFeatureInteger(FEATURE_PARAM_MAP_1_NAME, DEFAULT_FEATURE_MAP_1_VALUE);
			}
			return FeatureMap1IntValue;
		}
		private set;
	}

	@TestVisible
	public static Integer FeatureMap2IntValue {
		get {
			if(FeatureMap2IntValue == null) {
				FeatureMap2IntValue = getPackageFeatureInteger(FEATURE_PARAM_MAP_2_NAME, DEFAULT_FEATURE_MAP_2_VALUE);
			}
			return FeatureMap2IntValue;
		}
		private set;
	}

	@TestVisible
	public static Integer FeatureMap3IntValue {
		get {
			if(FeatureMap3IntValue == null) {
				FeatureMap3IntValue = getPackageFeatureInteger(FEATURE_PARAM_MAP_3_NAME, DEFAULT_FEATURE_MAP_3_VALUE);
			}
			return FeatureMap3IntValue;
		}
		private set;
	}

	@TestVisible
	public static Integer FeatureMap4IntValue {
		get {
			if(FeatureMap4IntValue == null) {
				FeatureMap4IntValue = getPackageFeatureInteger(FEATURE_PARAM_MAP_4_NAME, DEFAULT_FEATURE_MAP_4_VALUE);
			}
			return FeatureMap4IntValue;
		}
		private set;
	}

	@TestVisible
	public static Integer FeatureMap5IntValue {
		get {
			if(FeatureMap5IntValue == null) {
				FeatureMap5IntValue = getPackageFeatureInteger(FEATURE_PARAM_MAP_5_NAME, DEFAULT_FEATURE_MAP_5_VALUE);
			}
			return FeatureMap5IntValue;
		}
		private set;
	}

	public static Map<Integer, Integer> getBitmapFromInteger(Integer intValue) {
		Map<Integer, Integer> bitmap = new Map<Integer, Integer>();
		for(Integer i = 0; i <= MAX_USED_BITS_IN_INTEGER; i++) {
			Integer bitMask = (Integer)Math.pow(2, i);
			Integer bitValue = (intValue & bitMask) >> i;
			bitmap.put(i, bitValue);
		}
		return bitmap;
	}

	public static Integer getIntegerFromBitmap(Map<Integer, Integer> bitmap) {
		Integer intValue = 0;
		for(Integer i = bitmap.size() - 1; i >= 0; i--){
			intValue += bitmap.get(i);
			if(i != 0) intValue <<= 1;
		}
		return intValue;
	}

	public static String ChargifyProductEdition {
		get {
			if(ChargifyProductEdition == null) {
				Integer intValue = getIntegerFromBitmap(new Map<Integer, Integer>{
					0 => FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_CHARGIFY_PRODUCT_EDITION)) == true ? 1 : 0,
					1 => FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_CHARGIFY_PRODUCT_EDITION) + 1) == true ? 1 : 0
				});
				ChargifyProductEdition = CHARGIFY_PRODUCT_EDITION_MAP.get(intValue);
			}
			return ChargifyProductEdition;
		}
		private set;
	}

	public static Boolean BulkAPITrackingEnabled {
		get {
			if(BulkAPITrackingEnabled == null) {
				BulkAPITrackingEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_BULK_API_TRACKING_ENABLED));
			}
			return BulkAPITrackingEnabled;
		}
		private set;
	}

	public static Boolean NotificationIntegrationEnabled {
		get {
			if(NotificationIntegrationEnabled == null) {
				NotificationIntegrationEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_NOTIFICATION_INTEGRATION_ENABLED));
			}
			return NotificationIntegrationEnabled;
		}
		private set;
	}

	public static Boolean FlowDebugViewEnabled {
		get {
			if(FlowDebugViewEnabled == null) {
				FlowDebugViewEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_FLOW_DEBUG_VIEW_ENABLED));
			}
			return FlowDebugViewEnabled;
		}
		private set;
	}

	public static Boolean IntegrationDebugViewEnabled {
		get {
			if(IntegrationDebugViewEnabled == null) {
				IntegrationDebugViewEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_INTEGRATION_DEBUG_VIEW_ENABLED));
			}
			return IntegrationDebugViewEnabled;
		}
		private set;
	}

	public static Boolean NotificationForPharosErrors {
		get {
			if(NotificationForPharosErrors == null) {
				NotificationForPharosErrors = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_NOTIFICATIONS_FOR_PHAROS_ERRORS));
			}
			return NotificationForPharosErrors;
		}
		private set;
	}

	@TestVisible
	public static Boolean TeamsIntegrationEnabled {
		get {
			if(TeamsIntegrationEnabled == null) {
				TeamsIntegrationEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_TEAMS_INTEGRATION_ENABLED));
			}
			return TeamsIntegrationEnabled;
		}
		private set;
	}

	@TestVisible
	public static Boolean GitHubIntegrationEnabled {
		get {
			if(GitHubIntegrationEnabled == null) {
				GitHubIntegrationEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_GITHUB_INTEGRATION_ENABLED));
			}
			return GitHubIntegrationEnabled;
		}
		private set;
	}

	@TestVisible
	public static Boolean ChangeTrackingEnabled {
		get {
			if(ChangeTrackingEnabled == null) {
				ChangeTrackingEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_CHANGE_TRACKING_ENABLED));
			}
			return ChangeTrackingEnabled;
		}
		private set;
	}

	public static Boolean JiraIntegrationEnabled {
		get {
			if(JiraIntegrationEnabled == null) {
				JiraIntegrationEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_JIRA_INTEGRATION_ENABLED));
			}
			return JiraIntegrationEnabled;
		}
		private set;
	}

	public static Boolean SlackIntegrationEnabled {
		get {
			if(SlackIntegrationEnabled == null) {
				SlackIntegrationEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_SLACK_INTEGRATION_ENABLED));
			}
			return SlackIntegrationEnabled;
		}
		private set;
	}

	public static Boolean PagerDutyIntegrationEnabled {
		get {
			if(PagerDutyIntegrationEnabled == null) {
				PagerDutyIntegrationEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_PAGER_DUTY_INTEGRATION_ENABLED));
			}
			return PagerDutyIntegrationEnabled;
		}
		private set;
	}

	public static Boolean SplunkIntegrationEnabled {
		get {
			if(SplunkIntegrationEnabled == null) {
				SplunkIntegrationEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_SPLUNK_INTEGRATION_ENABLED));
			}
			return SplunkIntegrationEnabled;
		}
		private set;
	}

	public static Boolean MonitoringEnabled {
		get {
			if(MonitoringEnabled == null) {
				MonitoringEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_MONITORING_ENABLED));
			}
			return MonitoringEnabled;
		}
		private set;
	}

	public static Integer MaxMonitoringRules {
		get {
			if(MaxMonitoringRules == null) {
				MaxMonitoringRules = FeatureMap2.get(MAP_FEATURE2_INDEX_BY_NAME.get(FP_MAX_MONITORING_RULES));
			}
			return MaxMonitoringRules;
		}
		private set;
	}

	public static Boolean ArchivalEnabled {
		get {
			if(ArchivalEnabled == null) {
				ArchivalEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_ARCHIVAL_ENABLED));
			}
			return ArchivalEnabled;
		}
		private set;
	}

	public static Integer MaxArchivalRules {
		get {
			if(MaxArchivalRules == null) {
				MaxArchivalRules = FeatureMap2.get(MAP_FEATURE2_INDEX_BY_NAME.get(FP_MAX_ARCHIVAL_RULES));
			}
			return MaxArchivalRules;
		}
		private set;
	}

	public static Integer MaxJiraRules {
		get {
			if(MaxJiraRules == null) {
				MaxJiraRules = FeatureMap2.get(MAP_FEATURE3_INDEX_BY_NAME.get(FP_MAX_JIRA_RULES));
			}
			return MaxJiraRules;
		}
		private set;
	}

	public static Integer MaxConnectedOrgs {
		get {
			if(MaxConnectedOrgs == null) {
				MaxConnectedOrgs = FeatureMap2.get(MAP_FEATURE2_INDEX_BY_NAME.get(FP_MAX_CONNECTED_ORGS));
			}
			return MaxConnectedOrgs;
		}
		private set;
	}

	public static Integer MaxNotificationRules {
		get {
			if(MaxNotificationRules == null) {
				MaxNotificationRules = FeatureMap3.get(MAP_FEATURE3_INDEX_BY_NAME.get(FP_MAX_NOTIFICATION_RULES));
			}
			return MaxNotificationRules;
		}
		private set;
	}

	public static Boolean SensitiveDataMaskingEnabled {
		get {
			if(SensitiveDataMaskingEnabled == null) {
				SensitiveDataMaskingEnabled = FeatureMap1.get(MAP_FEATURE1_INDEX_BY_NAME.get(FP_SENSITIVE_DATA_MASK_ENABLED));
			}
			return SensitiveDataMaskingEnabled;
		}
		private set;
	}

	// Cache params

	public static Integer RequestAuditTrailTTL {
		get {
			if(RequestAuditTrailTTL == null) {
				RequestAuditTrailTTL = TTL_MAP.get(FeatureMap4.get(MAP_FEATURE4_INDEX_BY_NAME.get(FP_REQUEST_AUDIT_TRAIL_TTL)));
			}
			return RequestAuditTrailTTL;
		}
		private set;
	}

	public static Integer RequestAuthSessionsTTL {
		get {
			if(RequestAuthSessionsTTL == null) {
				RequestAuthSessionsTTL = TTL_MAP.get(FeatureMap4.get(MAP_FEATURE4_INDEX_BY_NAME.get(FP_REQUEST_AUTH_SESSION_TTL)));
			}
			return RequestAuthSessionsTTL;
		}
		private set;
	}

	public static Integer RequestPackagesInfoTTL {
		get {
			if(RequestPackagesInfoTTL == null) {
				RequestPackagesInfoTTL = TTL_MAP.get(FeatureMap4.get(MAP_FEATURE4_INDEX_BY_NAME.get(FP_REQUEST_PACKAGES_INFO_TTL)));
			}
			return RequestPackagesInfoTTL;
		}
		private set;
	}

	public static Integer RequestAsyncJobsTTL {
		get {
			if(RequestAsyncJobsTTL == null) {
				RequestAsyncJobsTTL = TTL_MAP.get(FeatureMap4.get(MAP_FEATURE4_INDEX_BY_NAME.get(FP_REQUEST_ASYNC_JOBS_TTL)));
			}
			return RequestAsyncJobsTTL;
		}
		private set;
	}

	public static Integer RequestUserInfoTTL {
		get {
			if(RequestUserInfoTTL == null) {
				RequestUserInfoTTL = TTL_MAP.get(FeatureMap4.get(MAP_FEATURE4_INDEX_BY_NAME.get(FP_REQUEST_USER_INFO_TTL)));
			}
			return RequestUserInfoTTL;
		}
		private set;
	}

	public static Integer RequestSobjectDescribeTTL {
		get {
			if(RequestSobjectDescribeTTL == null) {
				RequestSobjectDescribeTTL = TTL_MAP.get(FeatureMap4.get(MAP_FEATURE4_INDEX_BY_NAME.get(FP_REQUEST_SOBJECT_DESCRIBE_TTL)));
			}
			return RequestSobjectDescribeTTL;
		}
		private set;
	}

	public static Integer RequestStackTraceTTL {
		get {
			if(RequestStackTraceTTL == null) {
				RequestStackTraceTTL = TTL_MAP.get(FeatureMap4.get(MAP_FEATURE4_INDEX_BY_NAME.get(FP_REQUEST_STACK_TRACE_TTL)));
			}
			return RequestStackTraceTTL;
		}
		private set;
	}

	public static Integer RequestDeploymentJobsTTL {
		get {
			if(RequestDeploymentJobsTTL == null) {
				RequestDeploymentJobsTTL = TTL_MAP.get(FeatureMap4.get(MAP_FEATURE4_INDEX_BY_NAME.get(FP_REQUEST_DEPLOYMENT_JOBS_TTL)));
			}
			return RequestDeploymentJobsTTL;
		}
		private set;
	}

	public static Integer RequestEncryptedTokenTTL {
		get {
			if(RequestEncryptedTokenTTL == null) {
				RequestEncryptedTokenTTL = TTL_MAP.get(FeatureMap4.get(MAP_FEATURE4_INDEX_BY_NAME.get(FP_REQUEST_ENCRYPTED_TOKEN_TTL)));
			}
			return RequestEncryptedTokenTTL;
		}
		private set;
	}

}