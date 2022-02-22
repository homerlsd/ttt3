public with sharing class TestDataGenerator {

	public static final Integer TEST_EMAIL_EXCEPTION_STEP_TIME = 1;
	public static final Integer TEST_EMAIL_EXCEPTION_LIMIT_TIME = 20;
	public static final String TEST_EMAIL_EXCEPTION_KEY_USER = 'userid';
	public static final String TEST_EMAIL_EXCEPTION_KEY_START_TIME = 'startat';

	public class SchedulerInputData {
		public String userId;
		public DateTime startAt;

		public SchedulerInputData(String userId, DateTime startAt) {
			this.userId = userId;
			this.startAt = startAt;
		}
	}

	public static Object testEmailExceptionSendMeAnEmail() {
		startCheckTestEmailExceptionLog(JSON.serialize(new SchedulerInputData(CURRENT_USER_ID_15, DateTime.now())));
		return true;
	}

	@Future(Callout=true)
	public static void startCheckTestEmailExceptionLogFuture(String data) {
		startCheckTestEmailExceptionLog(data);
	}

	public static final String TEST_EMAIL_EXCEPTION_JOB_NAME = 'Status Email Exception Job Started At';
	public static final String TEST_TIME_LIMIT_EXCEEDED = 'Test Time limit exceeded';

	public static void startCheckTestEmailExceptionLog(String data) {
		abortCronTriggerJob(TEST_EMAIL_EXCEPTION_JOB_NAME);

		SchedulerInputData sid = (SchedulerInputData)JSON.deserialize(data, SchedulerInputData.class);
		String userId = sid.userId;
		Datetime startAt = sid.startAt;
		String nextFireTime;

		// over limit
		DateTime dtLimit = startAt.addMinutes(TEST_EMAIL_EXCEPTION_LIMIT_TIME);
		if(Datetime.now() > dtLimit || startAt == null){
			sendTestEmailExceptionLogEmail(userId, TEST_TIME_LIMIT_EXCEEDED);
		}
		else {
			Boolean emailExceptionLogReady = false;
			TestResultLogs logResult = getTestEmailExceptionLog();
			if(!logResult.createdLogs.isEmpty()) {
				emailExceptionLogReady = true;
			}

			if(emailExceptionLogReady) {
				String errorLog = '';
				if(!logResult.errorLogs.isEmpty()) {
					errorLog = ConfigUtil.BASE_URL + '/' + logResult.errorLogs.get(0).Id;
				}
				sendTestEmailExceptionLogEmail(userId, errorLog);
			}
			else {
				nextFireTime = getNextFireTime(DateTime.now().addMinutes(TEST_EMAIL_EXCEPTION_STEP_TIME));
			}

			if(String.isNotBlank(nextFireTime)) {
				TestDataGeneratorScheduler s = new TestDataGeneratorScheduler(TestDataGeneratorScheduler.MODE.CHECK_TEST_EMAIL_EXCEPTION, JSON.serialize(sid));

				Id newJobId;
				try {
					newJobId = System.schedule(TEST_EMAIL_EXCEPTION_JOB_NAME + ' ' + String.valueOf(Datetime.now()), nextFireTime, s);
				}
				catch(Exception e){}
			}

		}
	}

	public static final String TEST_EMAIL_EXCEPTION_EMAIL_TEMPLATE_NAME = 'Test_Email_Exception_Log';
	public static final String TEST_EMAIL_EXCEPTION_EMAIL_TEMPLATE_NAME_FAILED = 'Test_Email_Exception_Log_Fail';

	public static void sendTestEmailExceptionLogEmail(String userId, String error) {
		Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();

		message.setTargetObjectId(userId);
		message.setUseSignature(false);
		message.setBccSender(false);
		message.setSaveAsActivity(false);

		String emailTemplateName = String.isNotBlank(error) ? TEST_EMAIL_EXCEPTION_EMAIL_TEMPLATE_NAME_FAILED : TEST_EMAIL_EXCEPTION_EMAIL_TEMPLATE_NAME;
		EmailTemplate emailTemplate = getEmailTemplateByDeveloperName(emailTemplateName);
		setSubjectBody(message, emailTemplate, ConfigUtil.BASE_URL + '/apex/' + ConfigUtil.NameSpacePrefix + 'Admin#/quick-start/quick-test', error);

		Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
		Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
	}


	public static final Integer MONITORING_EVENTS_STEP_TIME = 1;
	public static final Integer MONITORING_EVENTS_LIMIT_TIME = 20;
	public static final String MONITORING_EVENTS_KEY_USER = 'userid';
	public static final String MONITORING_EVENTS_KEY_START_TIME = 'startat';

	public static Object monitoringTestSendMeAnEmail() {
		startCheckMonitoringEvents(JSON.serialize(new SchedulerInputData(CURRENT_USER_ID_15, DateTime.now())));
		return true;
	}

	public static void abortCronTriggerJob(String jobName) {
		String fullJobName = jobName + '%';
		for(CronTrigger ct : [SELECT Id, CronJobDetail.Name, CronJobDetail.JobType
			FROM CronTrigger
			WHERE CronJobDetail.Name LIKE :fullJobName]){
			try{
				System.abortJob(ct.id);
			}
			catch(Exception e) {}
		}
	}

	public static final String CHECK_MONITORING_EVENTS_JOB_NAME = 'Status Monitoring Events Job Started At';

	public static void startCheckMonitoringEvents(String data) {
		abortCronTriggerJob(CHECK_MONITORING_EVENTS_JOB_NAME);

		SchedulerInputData sid = (SchedulerInputData)JSON.deserialize(data, SchedulerInputData.class);
		String userId = sid.userId;
		Datetime startAt = sid.startAt;
		String nextFireTime;

		// over limit
		DateTime dtLimit = startAt.addMinutes(TEST_EMAIL_EXCEPTION_LIMIT_TIME);
		if(Datetime.now() > dtLimit || startAt == null){
			sendMonitoringTestEmail(userId, TEST_TIME_LIMIT_EXCEEDED);
		}
		else {
			Boolean spikeTestReady = false;
			Boolean impactTestReady = false;
			String errorLog = '';

			Map<String, Object> existRules = getExistMonitoringRules();
			if(existRules.containsKey(TEST_MONITORING_SPIKE_RULE_NAME)) {
				TestResultLogs spikeResult = getTestMonitoringSpikeRuleLog();
				if(!spikeResult.createdEvents.isEmpty()) {
					spikeTestReady = true;
				}
				if(!spikeResult.errorLogs.isEmpty()) {
					errorLog = ConfigUtil.BASE_URL + '/' + spikeResult.errorLogs.get(0).Id;
				}
			}
			if(existRules.containsKey(TEST_MONITORING_IMPACT_RULE_NAME)) {
				TestResultLogs impactResult = getTestMonitoringImpactRuleLog();
				if(!impactResult.createdEvents.isEmpty()) {
					impactTestReady = true;
				}
				if(!impactResult.errorLogs.isEmpty()) {
					errorLog = ConfigUtil.BASE_URL + '/' + impactResult.errorLogs.get(0).Id;
				}
			}

			if(spikeTestReady || impactTestReady) {
				sendMonitoringTestEmail(userId, errorLog);
			}
			else {
				nextFireTime = getNextFireTime(DateTime.now().addMinutes(MONITORING_EVENTS_STEP_TIME));
			}

			if(String.isNotBlank(nextFireTime)) {
				TestDataGeneratorScheduler s = new TestDataGeneratorScheduler(TestDataGeneratorScheduler.MODE.CEHCK_MONITORING_EVENTS, JSON.serialize(sid));

				Id newJobId;
				try {
					newJobId = System.schedule(CHECK_MONITORING_EVENTS_JOB_NAME + ' ' + String.valueOf(Datetime.now()), nextFireTime, s);
				}
				catch(Exception e){}
			}

		}
	}

	public static final String TEST_MONITORING_EVENTS_EMAIL_TEMPLATE_NAME = 'Test_Email_Monitoring_Events';
	public static final String TEST_MONITORING_EVENTS_EMAIL_TEMPLATE_NAME_FAIL = 'Test_Email_Monitoring_Events_Fail';

	public static void sendMonitoringTestEmail(String userId, String error) {
		Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();

		message.setTargetObjectId(userId);
		message.setUseSignature(false);
		message.setBccSender(false);
		message.setSaveAsActivity(false);

		String emailTemplateName = String.isNotBlank(error) ? TEST_MONITORING_EVENTS_EMAIL_TEMPLATE_NAME_FAIL : TEST_MONITORING_EVENTS_EMAIL_TEMPLATE_NAME;
		EmailTemplate emailTemplate = getEmailTemplateByDeveloperName(emailTemplateName);
		setSubjectBody(message, emailTemplate, ConfigUtil.BASE_URL + '/apex/' + ConfigUtil.NameSpacePrefix + 'Admin#/quick-start/monitoring-setup', error);

		Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
		Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
	}

	public static void setSubjectBody(Messaging.SingleEmailMessage message, EmailTemplate emailTemplate, String link, String error) {
		String subject = emailTemplate.Subject;
		String body = emailTemplate.Body;
		body = body.replace('<link>', link);
		body = body.replace('<error>', error);
		message.setSubject(subject);
		message.setPlainTextBody(body);
	}

	public static EmailTemplate getEmailTemplateByDeveloperName(String devName) {
		EmailTemplate emailTemplate = [SELECT Id,Subject,Description,HtmlValue,DeveloperName,Body
			FROM EmailTemplate
			WHERE DeveloperName = :devName
			LIMIT 1
		];
		return emailTemplate;
	}

	@Future(Callout=true)
	public static void startCheckMonitoringEventsFuture(String data) {
		startCheckMonitoringEvents(data);
	}

	public static String getNextFireTime(DateTime dt) {
		String hour = String.valueOf(dt.hour());
		String min = String.valueOf(dt.minute());
		String ss = String.valueOf(dt.second());
		String nextFireTime = '0 ' + dt.minute() + ' ' + dt.hour() + ' ' + dt.day() + ' ' + dt.month() + ' ? ' + ' ' + dt.year();
		return nextFireTime;
	}


	public static final Integer SETUP_CONNECTED_APP_LIMIT_TIME = 10;
	public static final String TEST_EMAIL_SERVICE_KEY_USER = 'userid';

	@Future(Callout=true)
	public static void startCheckSetupConnectedAppFuture(String data) {
		startCheckSetupConnectedApp(data);
	}

	public static Object connectedAppSendMeAnEmail() {
		Map<String, Object> data = new Map<String, Object> {
			MONITORING_EVENTS_KEY_USER => CURRENT_USER_ID_15
		};
		return startCheckSetupConnectedApp(JSON.serialize(data));
	}

	public static final String STATUS_CONNECTED_APP_JOB_NAME = 'Status Connected App Job Started At';

	public static Boolean startCheckSetupConnectedApp(String data) {
		Boolean result = false;
		abortCronTriggerJob(STATUS_CONNECTED_APP_JOB_NAME);

		Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(data);
		String userId = String.valueOf(input.get(TEST_EMAIL_SERVICE_KEY_USER));

		if(String.isNotBlank(userId)
				&& ConfigUtil.CONNECTED_ORGS_SETTINGS.Connected_App_Created_At__c != null) {

			String nextFireTime;

			if(ConfigUtil.CONNECTED_ORGS_SETTINGS.Connected_App_Created_At__c.addMinutes(SETUP_CONNECTED_APP_LIMIT_TIME) > Datetime.now()){
				nextFireTime = getNextFireTime(ConfigUtil.CONNECTED_ORGS_SETTINGS.Connected_App_Created_At__c.addMinutes(SETUP_CONNECTED_APP_LIMIT_TIME + 1));
			}
			else if (ConfigUtil.CONNECTED_ORGS_SETTINGS.Connected_App_Created_At__c.addMinutes(SETUP_CONNECTED_APP_LIMIT_TIME) < Datetime.now()) {
				sendConnectedAppReadyEmail(userId);
				result = true;
			}

			if(String.isNotBlank(nextFireTime)) {
				TestDataGeneratorScheduler s = new TestDataGeneratorScheduler(TestDataGeneratorScheduler.MODE.CHECK_COMPLETE_SETUP_CONNECTED_APP_AND_SEND_EMAIL, JSON.serialize(input));
				Id jobId;
				try {
					jobId = System.schedule(STATUS_CONNECTED_APP_JOB_NAME + ' ' + String.valueOf(Datetime.now()), nextFireTime, s);
					result = true;
				}
				catch(System.AsyncException ae) {
					sendConnectedAppReadyEmail(userId);
					result = true;
				}
				catch(Exception e){}
			}
		}
		return result;
	}

	public static final String CONNECTED_APP_READY_EMAIL_TEMPLATE_NAME = 'Email_Connected_App_Ready';

	public static void sendConnectedAppReadyEmail(String userId) {
		Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();

		message.setTargetObjectId(userId);
		message.setUseSignature(false);
		message.setBccSender(false);
		message.setSaveAsActivity(false);

		EmailTemplate emailTemplate = getEmailTemplateByDeveloperName(CONNECTED_APP_READY_EMAIL_TEMPLATE_NAME);
		setSubjectBody(message, emailTemplate, ConfigUtil.BASE_URL + '/apex/' + ConfigUtil.NameSpacePrefix + 'Admin#/quick-start/connect-org', '');

		Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
		Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);

	}

	public static void deleteAllTestRules() {
		deleteTestMonitoringSpikeRule();
		deleteTestMonitoringImpactRule();
		deleteTestJiraRule();
	}

	public static void deleteTestJiraRule() {
		List<Rule__c> existRule = [
			SELECT Id
			FROM Rule__c
			WHERE Name__c = :TEST_JIRA_RULE_NAME
				AND Description__c = :TEST_JIRA_RULE_DESCRIPTION
				AND Type__c = :MonitoringUtil.RULE_TYPE_JIRA_UPDATE
			LIMIT 1
		];
		if (!existRule.isEmpty()) {
			delete existRule.get(0);
		}
	}

	public static void deleteTestMonitoringImpactRule() {
		List<Rule__c> existRule = [
			SELECT Id
			FROM Rule__c
			WHERE Name__c = :TEST_MONITORING_IMPACT_RULE_NAME
				AND Description__c = :TEST_MONITORING_IMPACT_RULE_DESCRIPTION
				AND Type__c = :MonitoringUtil.RULE_TYPE_MONITORING
			LIMIT 1
		];
		if(!existRule.isEmpty()) {
			delete existRule.get(0);
		}
	}

	public static void deleteTestMonitoringSpikeRule() {
		List<Rule__c> existRule = [
			SELECT Id
			FROM Rule__c
			WHERE Name__c = :TEST_MONITORING_SPIKE_RULE_NAME
				AND Description__c = :TEST_MONITORING_SPIKE_RULE_DESCRIPTION
				AND Type__c = :MonitoringUtil.RULE_TYPE_MONITORING
			LIMIT 1
		];
		if(!existRule.isEmpty()) {
			delete existRule.get(0);
		}
	}

	public static final String TEST_MONITORING_IMPACT_RULE_HASH1 = 'mNoZ+wesGr9FDlL2x22rxsxqM3GZSkQJb4mtuzSdlt0=';
	public static final String TEST_MONITORING_IMPACT_RULE_LOG_SUMMARY = 'Divide by 0';
	public static final String TEST_MONITORING_IMPACT_RULE_LOG_TYPE = 'System.MathException';
	public static final String TEST_MONITORING_IMPACT_RULE_LOG_CATEGORY = 'Error';
	public static final String TEST_MONITORING_IMPACT_RULE_LOG_AREA = 'Test Monitoring Impact Rule';
	public static final String TEST_MONITORING_IMPACT_RULE_LOG_STACKTRACE = 'Class.pharos.TestDataGenerator.impact.startJiraRuleTest: line 71, column 1';
	public static final String TEST_MONITORING_IMPACT_RULE_LOG_DETAILS = 'System.MathException: Divide by 0' + '\n\n' + TEST_MONITORING_IMPACT_RULE_LOG_STACKTRACE;
	public static final String TEST_MONITORING_IMPACT_RULE_NAME = 'MonitoringErrorsImpact';
	public static final String TEST_MONITORING_IMPACT_RULE_DESCRIPTION = 'more than 2 users are impacted in 1 hour.';
	public static final Integer TEST_MONITORING_IMPACT_THRESHOLD = 2;
	public static final Integer TEST_MONITORING_IMPACT_TIME_INTERVAL = 60;
	public static final Integer TEST_MONITORING_IMPACT_AGGREGATE_INTERVAL = null;
	public static final String TEST_MONITORING_IMPACT_KEY_SLACK_CHANNEL = 'slackChannel';
	public static final String TEST_MONITORING_IMPACT_KEY_EMAIL = 'email';

	public static Object createMonitoringImpactRule(Object data) {
		Boolean result = false;

		Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
		String slackChannel;
		String email;
		String teamId;
		String channelId;
		if(input.containsKey(TEST_MONITORING_IMPACT_KEY_SLACK_CHANNEL)) {
			slackChannel = String.valueOf(input.get(TEST_MONITORING_IMPACT_KEY_SLACK_CHANNEL));
		}
		if(input.containsKey(TEST_MONITORING_IMPACT_KEY_EMAIL)) {
			email = String.valueOf(input.get(TEST_MONITORING_IMPACT_KEY_EMAIL));
		}
		else if(input.containsKey(TEST_MONITORING_SPIKE_KEY_TEAM_ID)
				&& input.containsKey(TEST_MONITORING_SPIKE_KEY_CHANNEL_ID)) {
			teamId = String.valueOf(input.get(TEST_MONITORING_SPIKE_KEY_TEAM_ID));
			channelId = String.valueOf(input.get(TEST_MONITORING_SPIKE_KEY_CHANNEL_ID));
		}

		if(String.isNotBlank(slackChannel) || String.isNotBlank(email) || (String.isNotBlank(teamId) && String.isNotBlank(channelId))) {
			// setup test monitoring rule / ruleFilters / jiraDefaultAction / ruleAction
			Rule__c testMonitoringImpactRule = createTestMonitoringImpactRule();
			deleteSlackRuleActions(testMonitoringImpactRule.Id);
			List<RuleFilter__c> ruleFilters = createTestMonitoringImpactRuleFilters(testMonitoringImpactRule.Id);
			if(String.isNotBlank(slackChannel)) {
				Action__c slackAction = createSlackAction(slackChannel);
				RuleAction__c ruleAction = createMonitoringRuleAction(testMonitoringImpactRule.Id, slackAction.Id);
			}
			if(String.isNotBlank(email)) {
				Action__c emailAction = createEmailAction(email);
				RuleAction__c ruleAction = createMonitoringRuleAction(testMonitoringImpactRule.Id, emailAction.Id);
			}
			else if(String.isNotBlank(teamId) && String.isNotBlank(channelId)) {
				Action__c teamsAction = createTeamsAction(teamId, channelId);
				RuleAction__c ruleAction = createMonitoringRuleAction(testMonitoringImpactRule.Id, teamsAction.Id);
			}
			result = true;
		}
		else {
			result = false;
		}

		return result;
	}

	public static List<User> getUsers() {
		List<User> users = [
			SELECT Id
			FROM User
			WHERE Id != :CURRENT_USER_ID_15
				AND IsActive = true
				AND Profile.Name = 'System Administrator'
			LIMIT 1
		];
		users.add(new User(Id = CURRENT_USER_ID_15));
		return users;
	}

	public static Rule__c createTestMonitoringImpactRule() {
		Rule__c testRule;
		List<Rule__c> existRule = [
			SELECT Id
			FROM Rule__c
			WHERE Name__c = :TEST_MONITORING_IMPACT_RULE_NAME
				AND Description__c = :TEST_MONITORING_IMPACT_RULE_DESCRIPTION
				AND Type__c = :MonitoringUtil.RULE_TYPE_MONITORING
				AND Active__c = true
			LIMIT 1
		];
		if(!existRule.isEmpty()) {
			testRule = existRule.get(0);
		}
		else {
			testRule = new Rule__c();
			testRule.Name__c = TEST_MONITORING_IMPACT_RULE_NAME;
			testRule.Description__c = TEST_MONITORING_IMPACT_RULE_DESCRIPTION;
			testRule.Type__c = MonitoringUtil.RULE_TYPE_MONITORING;
			testRule.Subtype__c = MonitoringUtil.RULE_SUB_TYPE_IMPACT;
			testRule.Active__c = true;
			testRule.Index__c = 0;
			testRule.Threshold__c = TEST_MONITORING_IMPACT_THRESHOLD;
			testRule.AggregateType__c = MonitoringUtil.AggregateType.COUNT.name();
			testRule.ComparisonOperator__c = MonitoringUtil.COMPARISON_OPERATOR_GREATER_OR_EQUAL;
			testRule.EventTimeInterval__c = TEST_MONITORING_IMPACT_TIME_INTERVAL;
			testRule.AggregateInterval__c = TEST_MONITORING_IMPACT_AGGREGATE_INTERVAL;
			insert testRule;
		}
		return testRule;
	}

	public static List<RuleFilter__c> createTestMonitoringImpactRuleFilters(Id ruleId) {
		List<RuleFilter__c> result = createRuleBasicFilters(ruleId, false);
		RuleFilter__c groupFilterUserId;
		RuleFilter__c groupFilterHash1;

		List<RuleFilter__c> existGroupFilter = [
			SELECT Id, FieldName__c
			FROM RuleFilter__c
			WHERE Rule__c = :ruleId
				AND Comparison_Type__c = :MonitoringUtil.COMPARISON_TYPE_FIELD
				AND ComparisonOperator__c = :MonitoringUtil.COMPARISON_OPERATOR_EQUAL
				AND Field_Type__c = :MonitoringUtil.FIELD_TYPE_STRING
				AND (FieldName__c = :Schema.sObjectType.Log__c.fields.User_Id__c.getName()
					OR FieldName__c = :Schema.sObjectType.Log__c.fields.Hash_1__c.getName())
			LIMIT 2
		];

		for(RuleFilter__c gf : existGroupFilter) {
			if(gf.FieldName__c == Schema.sObjectType.Log__c.fields.User_Id__c.getName()) {
				groupFilterUserId = gf;
				result.add(groupFilterUserId);
			}
			else if(gf.FieldName__c == Schema.sObjectType.Log__c.fields.Hash_1__c.getName()) {
				groupFilterHash1 = gf;
				result.add(groupFilterHash1);
			}
		}


		if(groupFilterUserId == null) {
			groupFilterUserId = new RuleFilter__c();
			groupFilterUserId.Index__c = 1;
			groupFilterUserId.Rule__c = ruleId;
			groupFilterUserId.ComparisonOperator__c = MonitoringUtil.COMPARISON_OPERATOR_EQUAL;
			groupFilterUserId.FieldName__c = Schema.sObjectType.Log__c.fields.User_Id__c.getName();
			groupFilterUserId.Comparison_Type__c = MonitoringUtil.COMPARISON_TYPE_FIELD;
			groupFilterUserId.Field_Type__c = MonitoringUtil.FIELD_TYPE_STRING;
			insert groupFilterUserId;
			result.add(groupFilterUserId);
		}
		if(groupFilterHash1 == null) {
			groupFilterHash1 = new RuleFilter__c();
			groupFilterHash1.Index__c = 2;
			groupFilterHash1.Rule__c = ruleId;
			groupFilterHash1.ComparisonOperator__c = MonitoringUtil.COMPARISON_OPERATOR_EQUAL;
			groupFilterHash1.FieldName__c = Schema.sObjectType.Log__c.fields.Hash_1__c.getName();
			groupFilterHash1.Comparison_Type__c = MonitoringUtil.COMPARISON_TYPE_FIELD;
			groupFilterHash1.Field_Type__c = MonitoringUtil.FIELD_TYPE_STRING;
			insert groupFilterHash1;
			result.add(groupFilterHash1);
		}

		return result;
	}

	public static void deleteSlackRuleActions(Id ruleId) {
		delete [SELECT Id FROM RuleAction__c WHERE Rule__c = :ruleId];
	}

	public static Action__c createTeamsAction(String teamId, String channelId) {
		Action__c teamsAction;
		Id recordtypeId = Schema.SObjectType.Action__c.getRecordTypeInfosByName().get('Monitoring').getRecordtypeId();
		List<Action__c> existTeamsAction = [
			SELECT Id
			FROM Action__c
			WHERE Team_Id__c = :teamId
				AND Channel_Id__c = :channelId
				AND (Action_Type__c = :MonitoringUtil.ACTION_TYPE_TEAMS_NOTIFICATION OR Type__c = :MonitoringUtil.ACTION_TYPE_TEAMS_NOTIFICATION)
				AND RecordTypeId = :recordtypeId
			LIMIT 1
		];
		if(!existTeamsAction.isEmpty()) {
			teamsAction = existTeamsAction.get(0);
		}
		else {
			teamsAction = new Action__c();
			teamsAction.RecordTypeId = recordtypeId;
			teamsAction.Action_Type__c = MonitoringUtil.ACTION_TYPE_EMAIL_NOTIFICATION;
			teamsAction.Team_Id__c = teamId;
			teamsAction.Channel_Id__c = channelId;
			insert teamsAction;
		}
		return teamsAction;
	}

	public static Action__c createEmailAction(String email) {
		Action__c emailAction;
		Id recordtypeId = Schema.SObjectType.Action__c.getRecordTypeInfosByName().get('Monitoring').getRecordtypeId();
		List<Action__c> existEmailAction = [
			SELECT Id
			FROM Action__c
			WHERE EmailTo__c = :email
				AND Type__c = :MonitoringUtil.ACTION_TYPE_EMAIL_NOTIFICATION
				AND RecordTypeId = :recordtypeId
				AND Description__c = :email
			LIMIT 1
		];
		if(!existEmailAction.isEmpty()) {
			emailAction = existEmailAction.get(0);
		}
		else {
			emailAction = new Action__c();
			emailAction.RecordTypeId = recordtypeId;
			emailAction.Action_Type__c = MonitoringUtil.ACTION_TYPE_EMAIL_NOTIFICATION;
			emailAction.EmailTo__c = email;
			emailAction.Description__c = email;
			insert emailAction;
		}
		return emailAction;
	}

	public static Action__c createSlackAction(String slackChannel) {
		Action__c slackAction;
		String subject = '{!' + Schema.sObjectType.Event__c.getName() + '.' + Schema.sObjectType.Event__c.fields.Rule_Description__c.getName() + '}';
		String body = '{!' + Schema.sObjectType.Event__c.getName() + '.' + Schema.sObjectType.Event__c.fields.Event_Details__c.getName() + '} \r\n ' +
			'More details can be found at: ' + '{!' + Schema.sObjectType.Event__c.getName() + '.Link}';
		Id recordtypeId = Schema.SObjectType.Action__c.getRecordTypeInfosByName().get('Monitoring').getRecordtypeId();
		List<Action__c> existSlackAction = [
			SELECT Id
			FROM Action__c
			WHERE SlackChannels__c = :slackChannel
				AND Type__c = :MonitoringUtil.ACTION_TYPE_SLACK_NOTIFICATION
				AND RecordTypeId = :recordtypeId
				AND Description__c = :slackChannel
			LIMIT 1
		];
		if(!existSlackAction.isEmpty()) {
			slackAction = existSlackAction.get(0);
			slackAction.Subject__c = subject;
			slackAction.Body__c = body;
			update slackAction;
		}
		else {
			slackAction = new Action__c();
			slackAction.RecordTypeId = recordtypeId;
			slackAction.Action_Type__c = MonitoringUtil.ACTION_TYPE_SLACK_NOTIFICATION;
			slackAction.SlackChannels__c = slackChannel;
			slackAction.Description__c = slackChannel;
			slackAction.Subject__c = subject;
			slackAction.Body__c = body;
			insert slackAction;
		}
		return slackAction;
	}

	public static RuleAction__c createMonitoringRuleAction(Id ruleId, Id actionId) {
		RuleAction__c ruleAction;

		List<RuleAction__c> existRuleActions = [
			SELECT Id
			FROM RuleAction__c
			WHERE Action__c = :actionId
				AND Rule__c = :ruleId
			LIMIT 1
		];

		if(!existRuleActions.isEmpty()) {
			ruleAction = existRuleActions.get(0);
		}
		else {
			ruleAction = new RuleAction__c();
			ruleAction.Action__c = actionId;
			ruleAction.Rule__c = ruleId;
			insert ruleAction;
		}
		return ruleAction;
	}

	public static List<Log__c> getTestMonitoringImpactRuleLogs() {
		List<Log__c> logs = [
			SELECT Id, Name, Bug_Tracker__c, Jira_Integration_Status__c
			FROM Log__c
			WHERE Hash_1__c = :TEST_MONITORING_IMPACT_RULE_HASH1
		];
		return logs;
	}

	public static List<Log__c> getTestMonitoringImpactRuleRelatedErrorLogs(List<Id> logIds) {
		List<Log__c> logs = [
			SELECT Id, Name, Summary__c
			FROM Log__c
			WHERE Related_Id__c IN :logIds
		];
		return logs;
	}

	public static void deleteMonitoringImpactRuleLogs() {
		List<Log__c> logs = getTestMonitoringImpactRuleLogs();
		if(!logs.isEmpty()) {
			Map<Id, Log__c> mapLogs = new Map<Id, Log__c>(logs);
			List<Log__c> relatedErrors = getTestMonitoringImpactRuleRelatedErrorLogs(new List<Id>(mapLogs.keySet()));
			if(!relatedErrors.isEmpty()){
				delete relatedErrors;
			}
			delete logs;
		}
	}

	public static List<Event__c> getTestMonitoringImpactRuleEvents() {
		List<Event__c> events = new List<Event__c>();
		List<Rule__c> existRule = [
			SELECT Id
			FROM Rule__c
			WHERE Name__c = :TEST_MONITORING_IMPACT_RULE_NAME
				AND Description__c = :TEST_MONITORING_IMPACT_RULE_DESCRIPTION
				AND Type__c = :MonitoringUtil.RULE_TYPE_MONITORING
			LIMIT 1
		];
		if(!existRule.isEmpty()) {
			events = [SELECT Id, Name, Rule_Name__c FROM Event__c WHERE Rule__c = :existRule.get(0).Id];
		}

		return events;
	}

	public static void deleteMonitoringImpactRuleEvents() {
		List<Event__c> events = getTestMonitoringImpactRuleEvents();
		if(!events.isEmpty()) {
			delete events;
		}
	}

	public static TestResultLogs getTestMonitoringImpactRuleLog() {
		TestResultLogs result = new TestResultLogs();

		List<Log__c> logs = getTestMonitoringImpactRuleLogs();
		if(!logs.isEmpty()) {
			result.createdLogs.add(logs.get(0));
			List<Log__c> relatedErrors = getTestMonitoringImpactRuleRelatedErrorLogs(new List<Id>{logs.get(0).Id});
			if(!relatedErrors.isEmpty()) {
				result.errorLogs.add(relatedErrors.get(0));
			}
		}
		List<Event__c> events = getTestMonitoringImpactRuleEvents();
		if(!events.isEmpty()) {
			result.createdEvents = events;
		}

		return result;
	}



	public static final String TEST_MONITORING_SPIKE_RULE_HASH1 = 'TjeDNwf88pQnvmxmOebhTkiX15UGh+qtk9uUuF9fmZk=';
	public static final String TEST_MONITORING_SPIKE_RULE_LOG_SUMMARY = 'Divide by 0';
	public static final String TEST_MONITORING_SPIKE_RULE_LOG_TYPE = 'System.MathException';
	public static final String TEST_MONITORING_SPIKE_RULE_LOG_CATEGORY = 'Error';
	public static final String TEST_MONITORING_SPIKE_RULE_LOG_AREA = 'Test Monitoring Spike Rule';
	public static final String TEST_MONITORING_SPIKE_RULE_LOG_STACKTRACE = 'Class.pharos.TestDataGenerator.spike.startJiraRuleTest: line 71, column 1';
	public static final String TEST_MONITORING_SPIKE_RULE_LOG_DETAILS = 'System.MathException: Divide by 0' + '\n\n' + TEST_MONITORING_SPIKE_RULE_LOG_STACKTRACE;
	public static final String TEST_MONITORING_SPIKE_RULE_NAME = 'MonitoringErrorsSpike';
	public static final String TEST_MONITORING_SPIKE_RULE_DESCRIPTION = '5 or more errors in 1 hour.';
	public static final Integer TEST_MONITORING_SPIKE_THRESHOLD = 5;
	public static final Integer TEST_MONITORING_SPIKE_TIME_INTERVAL = 60;
	public static final String TEST_MONITORING_SPIKE_KEY_SLACK_CHANNEL = 'slackChannel';
	public static final String TEST_MONITORING_SPIKE_KEY_EMAIL = 'email';
	public static final String TEST_MONITORING_SPIKE_KEY_TEAM_ID = 'teamId';
	public static final String TEST_MONITORING_SPIKE_KEY_CHANNEL_ID = 'channelId';

	public static Map<String, Object> getExistMonitoringRules() {
		Map<String, Object> result = new Map<String, Object>();

		List<Rule__c> existRule = [
			SELECT Id, Name__c
			FROM Rule__c
			WHERE ((Name__c = :TEST_MONITORING_IMPACT_RULE_NAME AND Description__c = :TEST_MONITORING_IMPACT_RULE_DESCRIPTION)
				OR (Name__c = :TEST_MONITORING_SPIKE_RULE_NAME AND Description__c = :TEST_MONITORING_SPIKE_RULE_DESCRIPTION))
				AND Type__c = :MonitoringUtil.RULE_TYPE_MONITORING
			LIMIT 2
		];
		for(Rule__c rule : existRule) {
			result.put(rule.Name__c, true);
		}
		return result;
	}

	public static Object createMonitoringSpikeRule(Object data) {
		Boolean result = false;

		Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
		String slackChannel;
		String email;
		String teamId;
		String channelId;
		if(input.containsKey(TEST_MONITORING_SPIKE_KEY_SLACK_CHANNEL)
			&& input.get(TEST_MONITORING_SPIKE_KEY_SLACK_CHANNEL) != null
			&& String.isNotBlank(String.valueOf(input.get(TEST_MONITORING_SPIKE_KEY_SLACK_CHANNEL)))) {
			slackChannel = String.valueOf(input.get(TEST_MONITORING_SPIKE_KEY_SLACK_CHANNEL));
		}
		else if(input.containsKey(TEST_MONITORING_SPIKE_KEY_EMAIL)) {
			email = String.valueOf(input.get(TEST_MONITORING_SPIKE_KEY_EMAIL));
		}
		else if(input.containsKey(TEST_MONITORING_SPIKE_KEY_TEAM_ID)
			&& input.containsKey(TEST_MONITORING_SPIKE_KEY_CHANNEL_ID)) {
			teamId = String.valueOf(input.get(TEST_MONITORING_SPIKE_KEY_TEAM_ID));
			channelId = String.valueOf(input.get(TEST_MONITORING_SPIKE_KEY_CHANNEL_ID));
		}

		if(String.isNotBlank(slackChannel) || String.isNotBlank(email) || (String.isNotBlank(teamId) && String.isNotBlank(channelId))) {
			// setup test monitoring rule / ruleFilters / jiraDefaultAction / ruleAction
			Rule__c testMonitoringSpikeRule = createTestMonitoringSpikeRule();
			deleteSlackRuleActions(testMonitoringSpikeRule.Id);
			List<RuleFilter__c> ruleFilters = createTestMonitoringSpikeRuleFilters(testMonitoringSpikeRule.Id);
			if(String.isNotBlank(slackChannel)) {
				Action__c slackAction = createSlackAction(slackChannel);
				RuleAction__c ruleAction = createMonitoringRuleAction(testMonitoringSpikeRule.Id, slackAction.Id);
			}
			else if(String.isNotBlank(email)) {
				Action__c emailAction = createEmailAction(email);
				RuleAction__c ruleAction = createMonitoringRuleAction(testMonitoringSpikeRule.Id, emailAction.Id);
			}
			else if(String.isNotBlank(teamId) && String.isNotBlank(channelId)) {
				Action__c teamsAction = createTeamsAction(teamId, channelId);
				RuleAction__c ruleAction = createMonitoringRuleAction(testMonitoringSpikeRule.Id, teamsAction.Id);
			}
			result = true;
		}
		else {
			result = false;
		}

		return result;
	}

	public static Object startMonitoringRuleTest() {
		Boolean result = false;

		deleteMonitoringSpikeRuleLogs();
		deleteMonitoringSpikeRuleEvents();
		deleteMonitoringImpactRuleLogs();
		deleteMonitoringImpactRuleEvents();

		PassthroughtModeService.IncomingLogData data = new PassthroughtModeService.IncomingLogData();

		// create Logs for Monitoring Spike Test
		Log__c log = LogBuilder.getInstance()
			.category(TEST_MONITORING_SPIKE_RULE_LOG_CATEGORY)
			.summary(TEST_MONITORING_SPIKE_RULE_LOG_SUMMARY)
			.area(TEST_MONITORING_SPIKE_RULE_LOG_AREA)
			.type(TEST_MONITORING_SPIKE_RULE_LOG_TYPE)
			.stackTrace(TEST_MONITORING_SPIKE_RULE_LOG_STACKTRACE)
			.details(TEST_MONITORING_SPIKE_RULE_LOG_DETAILS)
			.build();

		DateTime dt1 = DateTime.now();
		DateTime foo1 = DateTime.now();
		for(integer i=0; i < TEST_MONITORING_SPIKE_THRESHOLD; i++) {
			Log__c l1 = log.clone(true, true);
			l1.First_Occurred_On__c = foo1;
			l1.Created_At__c = dt1;
			data.logs.add(l1);
			dt1 = dt1.addMinutes(-5);
		}

		// create Logs for Monitoring Impact Test
		Log__c log2 = LogBuilder.getInstance()
			.category(TEST_MONITORING_IMPACT_RULE_LOG_CATEGORY)
			.summary(TEST_MONITORING_IMPACT_RULE_LOG_SUMMARY)
			.area(TEST_MONITORING_IMPACT_RULE_LOG_AREA)
			.type(TEST_MONITORING_IMPACT_RULE_LOG_TYPE)
			.stackTrace(TEST_MONITORING_IMPACT_RULE_LOG_STACKTRACE)
			.details(TEST_MONITORING_IMPACT_RULE_LOG_DETAILS)
			.build();

		List<User> adminUsers = getUsers();
		DateTime dt2 = DateTime.now();
		DateTime foo2 = DateTime.now();
		for(integer i=0; i < TEST_MONITORING_IMPACT_THRESHOLD; i++) {
			for(User u : adminUsers) {
				Log__c l1 = log2.clone(true, true);
				l1.First_Occurred_On__c = foo2;
				l1.User_Id__c = u.Id;
				l1.Created_At__c = dt2;
				data.logs.add(l1);
				dt2 = dt2.addMinutes(-5);
			}
		}

		PassthroughtModeService.parseIncomingData(data);
		result = true;

		return result;
	}

	public static Rule__c createTestMonitoringSpikeRule() {
		Rule__c testRule;
		List<Rule__c> existRule = [
			SELECT Id
			FROM Rule__c
			WHERE Name__c = :TEST_MONITORING_SPIKE_RULE_NAME
				AND Description__c = :TEST_MONITORING_SPIKE_RULE_DESCRIPTION
				AND Type__c = :MonitoringUtil.RULE_TYPE_MONITORING
				AND Active__c = true
			LIMIT 1
		];
		if(!existRule.isEmpty()) {
			testRule = existRule.get(0);
		}
		else {
			testRule = new Rule__c();
			testRule.Name__c = TEST_MONITORING_SPIKE_RULE_NAME;
			testRule.Description__c = TEST_MONITORING_SPIKE_RULE_DESCRIPTION;
			testRule.Type__c = MonitoringUtil.RULE_TYPE_MONITORING;
			testRule.Subtype__c = MonitoringUtil.RULE_SUB_TYPE_SPIKE;
			testRule.Active__c = true;
			testRule.Index__c = 0;
			testRule.Threshold__c = TEST_MONITORING_SPIKE_THRESHOLD;
			testRule.AggregateType__c = MonitoringUtil.AggregateType.COUNT.name();
			testRule.ComparisonOperator__c = MonitoringUtil.COMPARISON_OPERATOR_GREATER_OR_EQUAL;
			testRule.FilterLogic__c = null;
			testRule.EventTimeInterval__c = TEST_MONITORING_SPIKE_TIME_INTERVAL;
			insert testRule;
		}
		return testRule;
	}

	public static List<RuleFilter__c> createTestMonitoringSpikeRuleFilters(Id ruleId) {
		return createRuleBasicFilters(ruleId, false);
	}

	public static List<Log__c> getTestMonitoringSpikeRuleLogs() {
		List<Log__c> logs = [
			SELECT Id, Name, Bug_Tracker__c, Jira_Integration_Status__c
			FROM Log__c
			WHERE Hash_1__c = :TEST_MONITORING_SPIKE_RULE_HASH1
		];
		return logs;
	}

	public static List<Log__c> getTestMonitoringSpikeRuleRelatedErrorLogs(List<Id> logIds) {
		List<Log__c> logs = [
			SELECT Id, Name, Summary__c
			FROM Log__c
			WHERE Related_Id__c IN :logIds
		];
		return logs;
	}

	public static void deleteMonitoringSpikeRuleLogs() {
		List<Log__c> logs = getTestMonitoringSpikeRuleLogs();
		if(!logs.isEmpty()) {
			Map<Id, Log__c> mapLogs = new Map<Id, Log__c>(logs);
			List<Log__c> relatedErrors = getTestMonitoringSpikeRuleRelatedErrorLogs(new List<Id>(mapLogs.keySet()));
			if(!relatedErrors.isEmpty()){
				delete relatedErrors;
			}
			delete logs;
		}
	}

	public static List<Event__c> getTestMonitoringSpikeRuleEvents() {
		List<Event__c> events = new List<Event__c>();
		List<Rule__c> existRule = [
			SELECT Id
			FROM Rule__c
			WHERE Name__c = :TEST_MONITORING_SPIKE_RULE_NAME
			AND Description__c = :TEST_MONITORING_SPIKE_RULE_DESCRIPTION
			AND Type__c = :MonitoringUtil.RULE_TYPE_MONITORING
			LIMIT 1
		];
		if(!existRule.isEmpty()) {
			events = [SELECT Id, Name, Rule_Name__c FROM Event__c WHERE Rule__c = :existRule.get(0).Id];
		}

		return events;
	}

	public static void deleteMonitoringSpikeRuleEvents() {
		List<Event__c> events = getTestMonitoringSpikeRuleEvents();
		if(!events.isEmpty()) {
			delete events;
		}
	}

	public static TestResultLogs getTestMonitoringSpikeRuleLog() {
		TestResultLogs result = new TestResultLogs();

		List<Log__c> logs = getTestMonitoringSpikeRuleLogs();
		if(!logs.isEmpty()) {
			result.createdLogs.add(logs.get(0));
			List<Log__c> relatedErrors = getTestMonitoringSpikeRuleRelatedErrorLogs(new List<Id>{logs.get(0).Id});
			if(!relatedErrors.isEmpty()) {
				result.errorLogs.add(relatedErrors.get(0));
			}
		}
		List<Event__c> events = getTestMonitoringSpikeRuleEvents();
		if(!events.isEmpty()) {
			result.createdEvents = events;
		}

		return result;
	}

	public static List<RuleFilter__c> createRuleBasicFilters(Id ruleId) {
		return createRuleBasicFilters(ruleId, true);
	}

	public static List<RuleFilter__c> createRuleBasicFilters(Id ruleId, Boolean createIsNewFilter) {
		RuleFilter__c isNewFilter;
		RuleFilter__c orgNameFilter;

		List<RuleFilter__c> existRuleFilters = [
			SELECT Id, FieldName__c
			FROM RuleFilter__c
			WHERE Rule__c = :ruleId
			AND ComparisonOperator__c = :MonitoringUtil.COMPARISON_OPERATOR_EQUAL
			AND Comparison_Type__c = :MonitoringUtil.COMPARISON_TYPE_VALUE
			AND (Field_Type__c = :MonitoringUtil.FIELD_TYPE_STRING OR Field_Type__c = :MonitoringUtil.FIELD_TYPE_BOOLEAN)
			AND (Value__c = 'true' OR Value__c = :CURRENT_CONNECTED_ORG_TITLE OR Value__c = :TEST_MONITORING_SPIKE_RULE_HASH1)
			AND (FieldName__c = :Schema.sObjectType.Log__c.fields.Is_New__c.getName()
			OR FieldName__c = :Schema.sObjectType.Log__c.fields.Organization_Name__c.getName())
			LIMIT 2
		];

		for(RuleFilter__c rf : existRuleFilters) {
			if(rf.FieldName__c == Schema.sObjectType.Log__c.fields.Is_New__c.getName()) {
				isNewFilter = rf;
			}
			if(rf.FieldName__c == Schema.sObjectType.Log__c.fields.Organization_Name__c.getName()) {
				orgNameFilter = rf;
			}
		}

		if(createIsNewFilter && isNewFilter == null) {
			isNewFilter = new RuleFilter__c();
			isNewFilter.Index__c = 2;
			isNewFilter.Rule__c = ruleId;
			isNewFilter.ComparisonOperator__c = MonitoringUtil.COMPARISON_OPERATOR_EQUAL;
			isNewFilter.FieldName__c = Schema.sObjectType.Log__c.fields.Is_New__c.getName();
			isNewFilter.Value__c = 'true';
			isNewFilter.Comparison_Type__c = MonitoringUtil.COMPARISON_TYPE_VALUE;
			isNewFilter.Field_Type__c = MonitoringUtil.FIELD_TYPE_BOOLEAN;
			insert isNewFilter;
		}

		if(orgNameFilter == null) {
			orgNameFilter = new RuleFilter__c();
			orgNameFilter.Index__c = 1;
			orgNameFilter.Rule__c = ruleId;
			orgNameFilter.ComparisonOperator__c = MonitoringUtil.COMPARISON_OPERATOR_EQUAL;
			orgNameFilter.FieldName__c = Schema.sObjectType.Log__c.fields.Organization_Name__c.getName();
			orgNameFilter.Value__c = CURRENT_CONNECTED_ORG_TITLE;
			orgNameFilter.Comparison_Type__c = MonitoringUtil.COMPARISON_TYPE_VALUE;
			orgNameFilter.Field_Type__c = MonitoringUtil.FIELD_TYPE_STRING;
			insert orgNameFilter;
		}

		return createIsNewFilter ? new List<RuleFilter__c>{isNewFilter, orgNameFilter} : new List<RuleFilter__c>{orgNameFilter};
	}


	public static final String TEST_SLACK_RULE_HASH1 = 'BURsXIQhXxkrNYjFtYNAhxgQ/rgK4qn6qfIOQo6nKPE=';
	public static final String TEST_SLACK_RULE_LOG_SUMMARY = 'Divide by 0';
	public static final String TEST_SLACK_RULE_LOG_TYPE = 'System.MathException';
	public static final String TEST_SLACK_RULE_LOG_CATEGORY = 'Error';
	public static final String TEST_SLACK_RULE_LOG_AREA = 'Test Slack Rule';
	public static final String TEST_SLACK_RULE_LOG_STACKTRACE = 'Class.pharos.TestDataGenerator.slack.startJiraRuleTest: line 71, column 1';
	public static final String TEST_SLACK_RULE_LOG_DETAILS = 'System.MathException: Divide by 0' + '\n\n' + TEST_SLACK_RULE_LOG_STACKTRACE;

	public static List<Log__c> getTestSlackRuleLogs() {
		List<Log__c> logs = [
			SELECT Id, Name, Bug_Tracker__c, Jira_Integration_Status__c
			FROM Log__c
			WHERE Hash_1__c = :TEST_SLACK_RULE_HASH1
		];
		return logs;
	}

	public static List<Log__c> getTestSlackRuleRelatedErrorLogs(List<Id> logIds) {
		List<Log__c> logs = [
			SELECT Id, Name, Summary__c
			FROM Log__c
			WHERE Related_Id__c IN :logIds
		];
		return logs;
	}

	public static void deleteTestSlackRuleLogs() {
		List<Log__c> logs = getTestSlackRuleLogs();
		if(!logs.isEmpty()) {
			Map<Id, Log__c> mapLogs = new Map<Id, Log__c>(logs);
			List<Log__c> relatedErrors = getTestSlackRuleRelatedErrorLogs(new List<Id>(mapLogs.keySet()));
			if(!relatedErrors.isEmpty()){
				delete relatedErrors;
			}
			delete logs;
		}

	}

	public static TestResultLogs getTestSlackRuleLog() {
		TestResultLogs result = new TestResultLogs();

		List<Log__c> logs = getTestSlackRuleLogs();
		if(!logs.isEmpty()) {
			result.createdLogs.add(logs.get(0));
			List<Log__c> relatedErrors = getTestSlackRuleRelatedErrorLogs(new List<Id>{logs.get(0).Id});
			if(!relatedErrors.isEmpty()) {
				result.errorLogs.add(relatedErrors.get(0));
			}
		}

		return result;
	}

	public static final String TEST_TEAMS_RULE_HASH1 = 'BURsXIQhXxkrNYjFtYNAhxgQ/rgK4qn6qfIOQo6nKPE=';
	public static final String TEST_TEAMS_RULE_LOG_SUMMARY = 'Divide by 0';
	public static final String TEST_TEAMS_RULE_LOG_TYPE = 'System.MathException';
	public static final String TEST_TEAMS_RULE_LOG_CATEGORY = 'Error';
	public static final String TEST_TEAMS_RULE_LOG_AREA = 'Test Teams Rule';
	public static final String TEST_TEAMS_RULE_LOG_STACKTRACE = 'Class.pharos.TestDataGenerator.teams.startJiraRuleTest: line 71, column 1';
	public static final String TEST_TEAMS_RULE_LOG_DETAILS = 'System.MathException: Divide by 0' + '\n\n' + TEST_SLACK_RULE_LOG_STACKTRACE;

	public static List<Log__c> getTestTeamsRuleRelatedErrorLogs(List<Id> logIds) {
		List<Log__c> logs = [
			SELECT Id, Name, Summary__c
			FROM Log__c
			WHERE Related_Id__c IN :logIds
		];
		return logs;
	}

	public static void deleteTestTeamsRuleLogs() {
		List<Log__c> logs = getTestTeamsRuleLogs();
		if(!logs.isEmpty()) {
			Map<Id, Log__c> mapLogs = new Map<Id, Log__c>(logs);
			List<Log__c> relatedErrors = getTestTeamsRuleRelatedErrorLogs(new List<Id>(mapLogs.keySet()));
			if(!relatedErrors.isEmpty()){
				delete relatedErrors;
			}
			delete logs;
		}
	}

	public static List<Log__c> getTestTeamsRuleLogs() {
		List<Log__c> logs = [
			SELECT Id, Name, Bug_Tracker__c, Jira_Integration_Status__c
			FROM Log__c
			WHERE Hash_1__c = :TEST_TEAMS_RULE_HASH1
		];
		return logs;
	}

	public static TestResultLogs getTestTeamsRuleLog() {
		TestResultLogs result = new TestResultLogs();

		List<Log__c> logs = getTestTeamsRuleLogs();
		if(!logs.isEmpty()) {
			result.createdLogs.add(logs.get(0));
			List<Log__c> relatedErrors = getTestTeamsRuleRelatedErrorLogs(new List<Id>{logs.get(0).Id});
			if(!relatedErrors.isEmpty()) {
				result.errorLogs.add(relatedErrors.get(0));
			}
		}

		return result;
	}

	public static Object startTeamsIntegrationTest() {
		Boolean result = false;

		//delete old test Logs and related errors
		deleteTestTeamsRuleLogs();

		// create Log for Slack Test
		Log__c log = LogBuilder.getInstance()
			.category(TEST_TEAMS_RULE_LOG_CATEGORY)
			.summary(TEST_TEAMS_RULE_LOG_SUMMARY)
			.area(TEST_TEAMS_RULE_LOG_AREA)
			.type(TEST_TEAMS_RULE_LOG_TYPE)
			.stackTrace(TEST_TEAMS_RULE_LOG_STACKTRACE)
			.details(TEST_TEAMS_RULE_LOG_DETAILS)
			.build();
		PassthroughtModeService.IncomingLogData data = new PassthroughtModeService.IncomingLogData();
		data.logs.add(log);
		PassthroughtModeService.parseIncomingData(data);
		result = true;

		return result;
	}

	public static Object startSlackIntegrationTest() {
		Boolean result = false;

		//delete old test Logs and related errors
		deleteTestSlackRuleLogs();

		// create Log for Slack Test
		Log__c log = LogBuilder.getInstance()
			.category(TEST_SLACK_RULE_LOG_CATEGORY)
			.summary(TEST_SLACK_RULE_LOG_SUMMARY)
			.area(TEST_SLACK_RULE_LOG_AREA)
			.type(TEST_SLACK_RULE_LOG_TYPE)
			.stackTrace(TEST_SLACK_RULE_LOG_STACKTRACE)
			.details(TEST_SLACK_RULE_LOG_DETAILS)
			.build();
		PassthroughtModeService.IncomingLogData data = new PassthroughtModeService.IncomingLogData();
		data.logs.add(log);
		PassthroughtModeService.parseIncomingData(data);
		result = true;

		return result;
	}


	public static final String TEST_JIRA_RULE_NAME = 'All new Logs pushed to Jira.';
	public static final String TEST_JIRA_RULE_DESCRIPTION = 'Create a ticket for every new Log record in this org.';
	public static final String TEST_JIRA_RULE_HASH1 = 'zO8Kv/8107D9rKy3uQuKE/FFpIYPeAITQS303kfca64=';
	public static final String TEST_JIRA_RULE_LOG_SUMMARY = 'Divide by 0';
	public static final String TEST_JIRA_RULE_LOG_TYPE = 'System.MathException';
	public static final String TEST_JIRA_RULE_LOG_CATEGORY = 'Error';
	public static final String TEST_JIRA_RULE_LOG_AREA = 'Test Jira Rule';
	public static final String TEST_JIRA_RULE_LOG_STACKTRACE = 'Class.pharos.TestDataGenerator.jira.startJiraRuleTest: line 71, column 1';
	public static final String TEST_JIRA_RULE_LOG_DETAILS = 'System.MathException: Divide by 0' + '\n\n' + TEST_JIRA_RULE_LOG_STACKTRACE;


	public class TestResultLogs {
		public List<Log__c> createdLogs;
		public List<Log__c> errorLogs;
		public List<Event__c> createdEvents;

		public TestResultLogs(){
			this.createdLogs = new List<Log__c>();
			this.errorLogs = new List<Log__c>();
			this.createdEvents = new List<Event__c>();
		}
	}

	public static List<Log__c> getTestJiraRuleLogs() {
		List<Log__c> logs = [
			SELECT Id, Name, Bug_Tracker__c, Jira_Integration_Status__c
			FROM Log__c
			WHERE Hash_1__c = :TEST_JIRA_RULE_HASH1
		];
		return logs;
	}

	public static List<Log__c> getTestJiraRuleRelatedErrorLogs(List<Id> logIds) {
		List<Log__c> logs = [
			SELECT Id, Name, Summary__c
			FROM Log__c
			WHERE Related_Id__c IN :logIds
		];
		return logs;
	}

	public static void deleteTestJiraRuleLogs() {
		List<Log__c> logs = getTestJiraRuleLogs();
		if(!logs.isEmpty()) {
			Map<Id, Log__c> mapLogs = new Map<Id, Log__c>(logs);
			List<Log__c> relatedErrors = getTestJiraRuleRelatedErrorLogs(new List<Id>(mapLogs.keySet()));
			if(!relatedErrors.isEmpty()){
				delete relatedErrors;
			}
			delete logs;
		}

	}

	public static TestResultLogs getTestJiraRuleLog() {
		TestResultLogs result = new TestResultLogs();

		List<Log__c> logs = getTestJiraRuleLogs();
		if(!logs.isEmpty()) {
			if(String.isNotBlank(logs.get(0).Bug_Tracker__c) || logs.get(0).Jira_Integration_Status__c == ConfigUtil.TICKET_CREATE_ERROR_STATUS) {
				result.createdLogs.add(logs.get(0));
			}
			List<Log__c> relatedErrors = getTestJiraRuleRelatedErrorLogs(new List<Id>{logs.get(0).Id});
			if(!relatedErrors.isEmpty()) {
				result.errorLogs.add(relatedErrors.get(0));
			}
		}

		return result;
	}

	public static Object startJiraRuleTest() {
		Boolean result = false;

		//delete old test Logs and related errors
		deleteTestJiraRuleLogs();

		// setup test jira rule / ruleFilters / jiraDefaultAction / ruleAction
		Rule__c testJiraRule = createTestJiraRule();
		List<RuleFilter__c> ruleFilters = createTestJiraRuleFilters(testJiraRule.Id);
		RuleAction__c ruleAction = createJiraDefaultRuleAction(testJiraRule.Id);

		// create Log for Jira Test
		Log__c log = LogBuilder.getInstance()
			.category(TEST_JIRA_RULE_LOG_CATEGORY)
			.summary(TEST_JIRA_RULE_LOG_SUMMARY)
			.area(TEST_JIRA_RULE_LOG_AREA)
			.type(TEST_JIRA_RULE_LOG_TYPE)
			.stackTrace(TEST_JIRA_RULE_LOG_STACKTRACE)
			.details(TEST_JIRA_RULE_LOG_DETAILS)
			.build();

		PassthroughtModeService.IncomingLogData data = new PassthroughtModeService.IncomingLogData();
		data.logs.add(log);
		PassthroughtModeService.parseIncomingData(data);
		result = true;

		return result;
	}

	@TestVisible
	private static String CURRENT_CONNECTED_ORG_ID_15 = UserInfo.getOrganizationId().left(15);
	@TestVisible
	private static String CURRENT_CONNECTED_ORG_NAME = UserInfo.getOrganizationName();
	@TestVisible
	private static String CURRENT_USER_ID_15 = UserInfo.getUserId().left(15);

	@TestVisible
	public static String CURRENT_CONNECTED_ORG_TITLE {
		get {
			if(CURRENT_CONNECTED_ORG_TITLE == null) {
				Connected_Org__c corg = Connected_Org__c.getInstance(CURRENT_CONNECTED_ORG_ID_15);
				CURRENT_CONNECTED_ORG_TITLE = corg.Title__c;
			}
			return CURRENT_CONNECTED_ORG_TITLE;
		}
		private set;
	}

	public static RuleAction__c createJiraDefaultRuleAction(Id ruleId) {
		RuleAction__c ruleAction;

		Action__c defaultJiraAction = ConfigUtil.getDefaultJiraAction();
		if(defaultJiraAction == null) {
			defaultJiraAction = ConfigUtil.createDefaultJiraAction();
		}

		List<RuleAction__c> existRuleActions = [
			SELECT Id
			FROM RuleAction__c
			WHERE Action__c = :defaultJiraAction.Id
				AND Rule__c = :ruleId
			LIMIT 1
		];

		if(!existRuleActions.isEmpty()) {
			ruleAction = existRuleActions.get(0);
		}
		else {
			ruleAction = new RuleAction__c();
			ruleAction.Action__c = defaultJiraAction.Id;
			ruleAction.Rule__c = ruleId;
			insert ruleAction;
		}
		return ruleAction;
	}

	public static List<RuleFilter__c> createTestJiraRuleFilters(Id ruleId) {
		return createRuleBasicFilters(ruleId);
	}

	public static Rule__c createTestJiraRule() {
		Rule__c testJiraRule;
		List<Rule__c> existRule = [
			SELECT Id
			FROM Rule__c
			WHERE Name__c = :TEST_JIRA_RULE_NAME
				AND Description__c = :TEST_JIRA_RULE_DESCRIPTION
				AND Type__c = :MonitoringUtil.RULE_TYPE_JIRA_UPDATE
			LIMIT 1
		];
		if(!existRule.isEmpty()) {
			testJiraRule = existRule.get(0);
		}
		else {
			testJiraRule = new Rule__c();
			testJiraRule.Name__c = TEST_JIRA_RULE_NAME;
			testJiraRule.Description__c = TEST_JIRA_RULE_DESCRIPTION;
			testJiraRule.Type__c = MonitoringUtil.RULE_TYPE_JIRA_UPDATE;
			testJiraRule.Active__c = true;
			testJiraRule.Index__c = 0;
			insert testJiraRule;
		}
		return testJiraRule;
	}


	public static void deleteTestEmailExceptionLogs() {
		List<Log__c> logs = getTestEmailExceptionLogs();
		if(!logs.isEmpty() && !ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Mode__c) {
			delete logs;
		}
	}

	public static List<Log__c> getTestEmailExceptionLogs() {
		List<Log__c> logs;
		if(ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Mode__c) {
			Connected_Org__c connectedPharosOrg = ConnectedOrgService.getPassthroughConnectedOrg();
			if(connectedPharosOrg != null) {
				String logServiceEndpoint = connectedPharosOrg.Instance_Url__c + ConfigUtil.PHAROS_REST_SERVICE_ENDPOINT + '?'
					+ LogRestService.HASH1_PARAMS + '=' + EncodingUtil.urlEncode(TEST_EMAIL_HASH1, 'UTF-8')
					+ '&' + LogRestService.LIMIT_PARAMS + '=1';

				String b = HttpUtils.get(
					logServiceEndpoint,
					HttpUtils.getHeaders(ConnectedOrgService.getConnectedOrgAccessToken(connectedPharosOrg)),
					200
				);
				Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(b);
				List<Object> logsMap = (List<Object>)responseMap.get('logs');
				logs = (List<Log__c>)JSON.deserialize(JSON.serialize(logsMap), List<Log__c>.class);
			}
		}
		else {
			logs = [SELECT Id, Name FROM Log__c WHERE Hash_1__c =:TEST_EMAIL_HASH1 ORDER BY CreatedDate DESC LIMIT 1];
		}
		return logs;
	}

	public static TestResultLogs getTestEmailExceptionLog() {
		TestResultLogs result = new TestResultLogs();
		result.createdLogs = getTestEmailExceptionLogs();
		return result;
	}

	public static Object sendTestEmailException() {
		Boolean result = false;
		deleteTestEmailExceptionLogs();
		String errorEmailHandlerAddress = AdminService.getPackageEmailServiceFunctionEmailAddress();
		if(String.isNotBlank(errorEmailHandlerAddress)) {
			Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
			message.toAddresses = new String[] {errorEmailHandlerAddress};
			message.subject = TEST_EMAIL_SUBJECT;
			message.plainTextBody = TEST_EMAIL_BODY;
			Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
			Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);

			if (!results[0].success) {
				throw new TestDataGeneratorException(ERROR_SEND_TEST_EMAIL + results[0].errors[0].message);
			}
			else {
				result = true;
			}
		}
		else {
			throw new TestDataGeneratorException(ERROR_EMAIL_SERVICE_FUNCTION_NOT_EXIST);
		}
		return result;
	}

	public class TestDataGeneratorException extends Exception {}
	public static final String ERROR_EMAIL_SERVICE_FUNCTION_NOT_EXIST = 'ERROR_EMAIL_SERVICE_FUNCTION_NOT_EXIST';
	public static final String ERROR_SEND_TEST_EMAIL = 'ERROR_SEND_TEST_EMAIL:';
	public static final String TEST_EMAIL_HASH1 = 'sf9rZbdag4q9mPp8Tp8cRlUZhrMOKFRSGA21qlKKDO4=';
	public static final String TEST_EMAIL_SUBJECT = 'Developer script exception from '+CURRENT_CONNECTED_ORG_NAME+' : \'pharos.LogServiceBatchTest\' for job id \'7076g00000ScE4F\' : Attempt to de-reference a null object';
	public static final String TEST_EMAIL_BODY = 'Apex script unhandled exception by user/organization: '+CURRENT_USER_ID_15.left(15)+'/'+CURRENT_CONNECTED_ORG_ID_15+'\n' +
		'\n' +
		'Failed to process batch for class \'pharos.LogServiceBatchTest\' for job id \'7076g00000ScE4F\'\n' +
		'\n' +
		'caused by: System.NullPointerException: Attempt to de-reference a null object\n' +
		'\n' +
		'Class.pharos.LogServiceBatchTest.execute: line 14, column 1';


	public static final String TEST_PLATFORM_EVENT_LOG_HASH1 = 'FwnXHJHYfrtgCzX+TSyjb51+36MqTGuf3t4WF6MSOX8=';
	public static final String TEST_PLATFORM_EVENT_LOG_SUMMARY = 'Divide by 0';
	public static final String TEST_PLATFORM_EVENT_LOG_TYPE = 'System.MathException';
	public static final String TEST_PLATFORM_EVENT_LOG_CATEGORY = 'Error';
	public static final String TEST_PLATFORM_EVENT_LOG_AREA = 'Test Platform Event';
	public static final String TEST_PLATFORM_EVENT_LOG_STACKTRACE = 'Class.pharos.TestDataGenerator.slack.startPlatformEventTest: line 71, column 1';
	public static final String TEST_PLATFORM_EVENT_LOG_DETAILS = 'System.MathException: Divide by 0' + '\n\n' + TEST_PLATFORM_EVENT_LOG_STACKTRACE;

	public static List<Log__c> getTestPlatformEventLogs() {
		List<Log__c> logs = [
			SELECT Id, Name
			FROM Log__c
			WHERE Hash_1__c = :TEST_PLATFORM_EVENT_LOG_HASH1
		];
		return logs;
	}

	public static List<Log__c> getTestPlatformEventRelatedErrorLogs(List<Id> logIds) {
		List<Log__c> logs = [
			SELECT Id, Name, Summary__c
			FROM Log__c
			WHERE Related_Id__c IN :logIds
		];
		return logs;
	}

	public static void deleteTestPlatformEventLogs() {
		List<Log__c> logs = getTestPlatformEventLogs();
		if(!logs.isEmpty()) {
			Map<Id, Log__c> mapLogs = new Map<Id, Log__c>(logs);
			List<Log__c> relatedErrors = getTestPlatformEventRelatedErrorLogs(new List<Id>(mapLogs.keySet()));
			if(!relatedErrors.isEmpty()){
				delete relatedErrors;
			}
			delete logs;
		}

	}

	public static TestResultLogs getPlatformEventTestLog() {
		TestResultLogs result = new TestResultLogs();

		List<Log__c> logs = getTestPlatformEventLogs();
		if(!logs.isEmpty()) {
			result.createdLogs.add(logs.get(0));
			List<Log__c> relatedErrors = getTestPlatformEventRelatedErrorLogs(new List<Id>{logs.get(0).Id});
			if(!relatedErrors.isEmpty()) {
				result.errorLogs.add(relatedErrors.get(0));
			}
		}

		return result;
	}

	public static Object startPlatformEventTest() {
		Boolean result = false;

		//delete old test Logs and related errors
		deleteTestPlatformEventLogs();

		// create Log for Slack Test
		Log__c log = LogBuilder.getInstance()
			.category(TEST_PLATFORM_EVENT_LOG_CATEGORY)
			.summary(TEST_PLATFORM_EVENT_LOG_SUMMARY)
			.area(TEST_PLATFORM_EVENT_LOG_AREA)
			.type(TEST_PLATFORM_EVENT_LOG_TYPE)
			.stackTrace(TEST_PLATFORM_EVENT_LOG_STACKTRACE)
			.details(TEST_PLATFORM_EVENT_LOG_DETAILS)
			.build();
		Logger.getInstance().add(log);
		Logger.getInstance().flush();
		result = true;

		return result;
	}

	public static final String CHECK_PLATFORM_EVENTS_JOB_NAME = 'Status Platform Events Job Started At';
	public static final String TEST_PLATFORM_EVENTS_EMAIL_TEMPLATE_NAME_FAILED = 'Test_Platform_Events_Log_Fail';
	public static final String TEST_PLATFORM_EVENTS_EMAIL_TEMPLATE_NAME = 'Test_Platform_Events_Log';

	public static Object platformEventTestSendMeAnEmail() {
		startCheckTestPlatformEvent(JSON.serialize(new SchedulerInputData(CURRENT_USER_ID_15, DateTime.now())));
		return true;
	}

	@Future(Callout=true)
	public static void startCheckTestPlatformEventFuture(String data) {
		startCheckTestPlatformEvent(data);
	}

	public static void startCheckTestPlatformEvent(String data) {
		abortCronTriggerJob(CHECK_PLATFORM_EVENTS_JOB_NAME);

		SchedulerInputData sid = (SchedulerInputData)JSON.deserialize(data, SchedulerInputData.class);
		String userId = sid.userId;
		Datetime startAt = sid.startAt;
		String nextFireTime;

		// over limit
		DateTime dtLimit = startAt.addMinutes(TEST_EMAIL_EXCEPTION_LIMIT_TIME);
		if(Datetime.now() > dtLimit || startAt == null){
			sendTestPlatformEventEmail(userId, TEST_TIME_LIMIT_EXCEEDED);
		}
		else {
			Boolean emailExceptionLogReady = false;
			TestResultLogs logResult = getPlatformEventTestLog();
			if(!logResult.createdLogs.isEmpty()) {
				emailExceptionLogReady = true;
			}

			if(emailExceptionLogReady) {
				String errorLog = '';
				if(!logResult.errorLogs.isEmpty()) {
					errorLog = ConfigUtil.BASE_URL + '/' + logResult.errorLogs.get(0).Id;
				}
				sendTestPlatformEventEmail(userId, errorLog);
			}
			else {
				nextFireTime = getNextFireTime(DateTime.now().addMinutes(TEST_EMAIL_EXCEPTION_STEP_TIME));
			}

			if(String.isNotBlank(nextFireTime)) {
				TestDataGeneratorScheduler s = new TestDataGeneratorScheduler(TestDataGeneratorScheduler.MODE.CEHCK_TEST_PLATFORM_EVENT, JSON.serialize(sid));

				Id newJobId;
				try {
					newJobId = System.schedule(CHECK_PLATFORM_EVENTS_JOB_NAME + ' ' + String.valueOf(Datetime.now()), nextFireTime, s);
				}
				catch(Exception e){}
			}

		}
	}

	public static void sendTestPlatformEventEmail(String userId, String error) {
		Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();

		message.setTargetObjectId(userId);
		message.setUseSignature(false);
		message.setBccSender(false);
		message.setSaveAsActivity(false);

		String emailTemplateName = String.isNotBlank(error) ? TEST_PLATFORM_EVENTS_EMAIL_TEMPLATE_NAME_FAILED : TEST_PLATFORM_EVENTS_EMAIL_TEMPLATE_NAME;
		EmailTemplate emailTemplate = getEmailTemplateByDeveloperName(emailTemplateName);
		setSubjectBody(message, emailTemplate, ConfigUtil.BASE_URL + '/apex/' + ConfigUtil.NameSpacePrefix + 'Admin#/log-util', error);

		Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
		Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
	}
}