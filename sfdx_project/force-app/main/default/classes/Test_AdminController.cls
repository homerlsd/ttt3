@IsTest
public class Test_AdminController {
    @IsTest
    static void test1 () {

        Test.startTest();

        ApexPages.currentPage().getParameters().put('dev', 'true');
        AdminController ctrl = new AdminController();
        String baseUrl = AdminController.baseUrl;

        Map<String, Object> payload = new Map<String, Object>{
            'method' => 'Unknown',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getEmailServiceData',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));


        payload = new Map<String, Object>{
            'method' => 'confirmEmailService',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getConfigurationOverviewData',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getJiraSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'resetJiraSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getJiraProjectUsers',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getOAuthSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getLogAccessData',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getLogAccessUsers',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getMasks',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getLoggerWrapperInfo',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getSplunkSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        Test.stopTest();

        System.assertNotEquals(null, payload);
    }

    @IsTest
    static void test2 () {

        Test.startTest();

        AdminController ctrl = new AdminController();

        Map<String, Object> payload = new Map<String, Object>{
            'method' => 'createEmailService',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));


        payload = new Map<String, Object>{
            'method' => 'saveJiraSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'saveJiraSettings2',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'saveConnecterAppDetails',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'createConnectedApp',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'addPermissionSetToUser',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'removePermissionSetAssignment',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'saveMask',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'deleteMask',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'testMask',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'manageServiceScheduler',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'generateSplunkToken',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'saveSplunkSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'sendMessageToSplunk',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'validateSplunkEventCollectorConnection',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));


        payload = new Map<String, Object>{
            'method' => 'getCreateMeta',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getConnectedOrgsInfo',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'updatePassthroughtMode',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'createConnectionOrg',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'updateConnectedOrg',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'schedulerEnabledUpdated',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'refreshConnectedOrgToken',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'testConnectedOrg',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'saveJiraFieldsMapping',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getCustomSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'saveCustomSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getSlackSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getSlackChannels',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'saveSlackSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        Test.stopTest();

        System.assertNotEquals(null, payload);
    }

    @IsTest
    static void test3 () {

        Test.startTest();

        AdminController ctrl = new AdminController();

        Map<String, Object> payload = new Map<String, Object>{
            'method' => 'setMonitoringSetting',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'setMonitoringRule',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'setNotificationRules',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getPagerDutySettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getPagerDutyServices',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'savePagerDutySettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'deleteLogRecordTypeMappings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'deleteMonitoringRule',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getActionRules',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'setArchivalSetting',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getArchivalSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'deleteArchivalRule',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'setArchivalRule',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'setJiraSetting',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getJiraRuleSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'deleteJiraRule',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'setJiraRule',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'resetTimerForNewConnectedApp',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'deleteConnectedOrg',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'deleteFakeConnectedOrg',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'setJiraRuleIndex',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getDefaultNotificationTemplate',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'deleteNotificationRule',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getOccurrenceLogs',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getAppPermissions',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'setJiraRuleIndex',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getInstalledVersion',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'flowErrorTracking',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getMonitoringSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        Test.stopTest();

        System.assertNotEquals(null, payload);
    }

    @IsTest
    static void test4 () {

        Test.startTest();

        AdminController ctrl = new AdminController();

        Map<String, Object> payload = new Map<String, Object>{
            'method' => 'emailToCaseTracking',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'setupRemoteSiteSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getMergeFields',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getRemoteSiteSettings',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getSelfConnectedOrgsInfo',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getTestEmailExceptionLog',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'setArchivalSetting',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getTestJiraRuleLog',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getSlackIntegrationTestLog',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'createMonitoringSpikeRule',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'createMonitoringImpactRule',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getTestMonitoringSpikeRuleLog',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getTestMonitoringImpactRuleLog',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getExistMonitoringRules',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getQuickStartState',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'setQuickStartState',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        payload = new Map<String, Object>{
            'method' => 'getUserInfo',
            'data' => ''
        };
        AdminController.remoteActionHandler(JSON.serialize(payload));

        Test.stopTest();

        System.assertNotEquals(null, payload);
    }

    @IsTest
    static void test5 () {

        Test.startTest();
        AdminController ac = new AdminController();
        System.assertNotEquals(null, ac.packageNamespace);
        System.assertNotEquals(null, AdminController.baseRemoteSiteSettings);
        System.assertNotEquals(null, AdminController.remoteSiteSettingsPayload);
        Test.stopTest();
    }

    @IsTest
    private static void testLogCategories() {
        Test.startTest();
        Map<String, Object> payload = new Map<String, Object> {
            'method' => 'getLogCategories',
            'data' => ''
        };
        String responseData = AdminController.remoteActionHandler(JSON.serialize(payload));
        System.assertNotEquals(null, responseData);
        Map<String, Object> mapResponse = (Map<String, Object>)JSON.deserializeUntyped(responseData);
        Map<String, Object> mapData = (Map<String, Object>)mapResponse.get('data');
        System.assertNotEquals(null, mapData.get('categories'));
        System.assertNotEquals(null, mapData.get('recordtypes'));
        System.assertNotEquals(null, mapData.get('mappings'));

        payload = new Map<String, Object> {
            'method' => 'setLogRecordTypeMappings',
            'data' => JSON.serialize(mapData.get('mappings'))
        };
        String responseSaveData = AdminController.remoteActionHandler(JSON.serialize(payload));
        System.assertNotEquals('success', responseSaveData);
        Test.stopTest();
    }


    private static Action__c createDefaultJiraAction() {
        Action__c defaultAction = new Action__c(
            Action_Type__c = 'Jira Notification',
            Subtype__c = 'Default'
        );
        insert defaultAction;
        return defaultAction;
    }

    @IsTest
    private static void testCreateRuleWithEdit_save_to_all() {

        Map<String, Object> ruleData = new Map<String, Object> {
            'notifications' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'subType' => null,
                    'type' => 'Slack Notification'
                }
            },
            'notificationsassignee' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'id' => null,
                    'monitoringruleid' => null,
                    'rulenotificationid' => null
                }
            },
            'monitoringrule' => new Map<String, Object> {
                'description' => 'test',
                'name' => '123123',
                'ruleEnabled' => true
            }
        };
        Map<String, Object> payload = new Map<String, Object> {
            'method' => 'setMonitoringRule',
            'data' => ruleData
        };

        String responseData = AdminController.remoteActionHandler(JSON.serialize(payload));
        System.assertNotEquals(null, responseData);

        List<Rule__c> rules = getRules();

        System.assertEquals(1, rules.size());
        System.assertEquals('Monitoring', rules.get(0).Type__c);

        System.assertEquals(1, rules.get(0).RuleActions__r.size());
        System.assertEquals('Slack Notification', rules.get(0).RuleActions__r.get(0).Action__r.Action_Type__c);
        System.assertEquals(null, rules.get(0).RuleActions__r.get(0).Action__r.Subtype__c);

        List<Action__c> actions = [SELECT Id FROM Action__c];
        System.assertEquals(1, actions.size());

        // update

        Map<String, Object> updateRuleData = new Map<String, Object> {
            'notifications' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'id' => actions.get(0).Id,
                    'body' => 'testbody2',
                    'subject' => 'testsubject2',
                    'subType' => null,
                    'type' => 'Slack Notification'
                }
            },
            'notificationsassignee' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'id' => rules.get(0).RuleActions__r.get(0).Id,
                    'monitoringruleid' => rules.get(0).Id,
                    'rulenotificationid' => actions.get(0).Id
                }
            },
            'monitoringrule' => new Map<String, Object> {
                'id' => rules.get(0).Id
            }
        };
        Map<String, Object> updatePayload = new Map<String, Object> {
            'method' => 'setNotificationRules',
            'data' => updateRuleData
        };

        String updateResponseData = AdminController.remoteActionHandler(JSON.serialize(updatePayload));
        System.assertNotEquals(null, updateResponseData);

        List<Rule__c> updatedRules = getRules();

        System.assertEquals(1, updatedRules.size());
        System.assertEquals('Monitoring', updatedRules.get(0).Type__c);

        System.assertEquals(1, updatedRules.get(0).RuleActions__r.size());
        System.assertEquals('Slack Notification', updatedRules.get(0).RuleActions__r.get(0).Action__r.Action_Type__c);
        System.assertEquals(null, updatedRules.get(0).RuleActions__r.get(0).Action__r.Subtype__c);
        System.assertEquals('testbody2', updatedRules.get(0).RuleActions__r.get(0).Action__r.Body__c);
        System.assertEquals('testsubject2', updatedRules.get(0).RuleActions__r.get(0).Action__r.Subject__c);

        List<Action__c> updatedActions = [SELECT Id FROM Action__c];
        System.assertEquals(1, updatedActions.size());
    }

    @IsTest
    private static void testCreateRuleWithEdit_save_as_new() {

        Map<String, Object> ruleData = new Map<String, Object> {
            'notifications' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'subType' => null,
                    'type' => 'Slack Notification'
                }
            },
            'notificationsassignee' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'id' => null,
                    'monitoringruleid' => null,
                    'rulenotificationid' => null
                }
            },
            'monitoringrule' => new Map<String, Object> {
                'description' => 'test',
                'name' => '123123',
                'ruleEnabled' => true
            }
        };
        Map<String, Object> payload = new Map<String, Object> {
            'method' => 'setMonitoringRule',
            'data' => ruleData
        };

        String responseData = AdminController.remoteActionHandler(JSON.serialize(payload));
        System.assertNotEquals(null, responseData);

        List<Rule__c> rules = getRules();

        System.assertEquals(1, rules.size());
        System.assertEquals('Monitoring', rules.get(0).Type__c);

        System.assertEquals(1, rules.get(0).RuleActions__r.size());
        System.assertEquals('Slack Notification', rules.get(0).RuleActions__r.get(0).Action__r.Action_Type__c);
        System.assertEquals(null, rules.get(0).RuleActions__r.get(0).Action__r.Subtype__c);

        List<Action__c> actions = [SELECT Id FROM Action__c];
        System.assertEquals(1, actions.size());

        // update

        Map<String, Object> updateRuleData = new Map<String, Object> {
            'notifications' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'id' => actions.get(0).Id,
                    'body' => 'testbody2',
                    'subject' => 'testsubject2',
                    'subType' => null,
                    'type' => 'Slack Notification'
                }
            },
            'notificationsassignee' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'id' => null,
                    'monitoringruleid' => rules.get(0).Id,
                    'rulenotificationid' => actions.get(0).Id
                }
            },
            'monitoringrule' => new Map<String, Object> {
                'id' => rules.get(0).Id
            }
        };
        Map<String, Object> updatePayload = new Map<String, Object> {
            'method' => 'setNotificationRules',
            'data' => updateRuleData
        };

        String updateResponseData = AdminController.remoteActionHandler(JSON.serialize(updatePayload));
        System.assertNotEquals(null, updateResponseData);

        List<Rule__c> updatedRules = getRules();

        System.assertEquals(1, updatedRules.size());
        System.assertEquals('Monitoring', updatedRules.get(0).Type__c);

        System.assertEquals(2, updatedRules.get(0).RuleActions__r.size());
        RuleAction__c createdNewRuleAction = null;
        for(RuleAction__c ra : updatedRules.get(0).RuleActions__r) {
            if(ra.Id != rules.get(0).RuleActions__r.get(0).Id) {
                createdNewRuleAction = ra;
            }
        }
        System.assertNotEquals(null, createdNewRuleAction);
        System.assertEquals('Slack Notification', createdNewRuleAction.Action__r.Action_Type__c);
        System.assertEquals(null, createdNewRuleAction.Action__r.Subtype__c);
        System.assertEquals('testbody2', createdNewRuleAction.Action__r.Body__c);
        System.assertEquals('testsubject2', createdNewRuleAction.Action__r.Subject__c);

        List<Action__c> updatedActions = [SELECT Id FROM Action__c];
        System.assertEquals(1, updatedActions.size());
    }

    @IsTest
    private static void testCreateJiraRuleWithDefaultTemplate_updateFromDefaultTemplate() {
        Action__c defaultActions = createDefaultJiraAction();

        Map<String, Object> ruleData = new Map<String, Object> {
            'notifications' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'subType' => 'Default',
                    'type' => 'Jira Notification'
                }
            },
            'notificationsassignee' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'id' => null,
                    'monitoringruleid' => null,
                    'rulenotificationid' => null
                }
            },
            'jirarule' => new Map<String, Object> {
                'description' => 'test',
                'name' => '123123',
                'ruleEnabled' => true
            }
        };
        Map<String, Object> payload = new Map<String, Object> {
            'method' => 'setJiraRule',
            'data' => ruleData
        };

        String responseData = AdminController.remoteActionHandler(JSON.serialize(payload));
        System.assertNotEquals(null, responseData);

        List<Rule__c> rules = getRules();

        System.assertEquals(1, rules.size());
        System.assertEquals('JIRA Update', rules.get(0).Type__c);

        System.assertEquals(1, rules.get(0).RuleActions__r.size());
        System.assertEquals('Jira Notification', rules.get(0).RuleActions__r.get(0).Action__r.Action_Type__c);
        System.assertEquals('Default', rules.get(0).RuleActions__r.get(0).Action__r.Subtype__c);
        System.assertEquals(defaultActions.Id, rules.get(0).RuleActions__r.get(0).Action__c);

        List<Action__c> actions = [SELECT Id FROM Action__c];
        System.assertEquals(1, actions.size());

        // update

        Map<String, Object> updateRuleData = new Map<String, Object> {
            'notifications' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'id' => actions.get(0).Id,
                    'body' => 'testbody',
                    'subject' => 'testsubject',
                    'subType' => null,
                    'type' => 'Jira Notification'
                }
            },
            'notificationsassignee' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'id' => rules.get(0).RuleActions__r.get(0).Id,
                    'monitoringruleid' => rules.get(0).Id,
                    'rulenotificationid' => actions.get(0).Id
                }
            },
            'jirarule' => new Map<String, Object> {
                'id' => rules.get(0).Id,
                'description' => 'test',
                'name' => '123123',
                'ruleEnabled' => true
            }
        };
        Map<String, Object> updatePayload = new Map<String, Object> {
            'method' => 'setJiraRule',
            'data' => updateRuleData
        };

        String updateResponseData = AdminController.remoteActionHandler(JSON.serialize(updatePayload));
        System.assertNotEquals(null, updateResponseData);

        List<Rule__c> updatedRules = getRules();

        System.assertEquals(1, updatedRules.size());
        System.assertEquals('JIRA Update', updatedRules.get(0).Type__c);

        System.assertEquals(1, updatedRules.get(0).RuleActions__r.size());
        System.assertEquals('Jira Notification', updatedRules.get(0).RuleActions__r.get(0).Action__r.Action_Type__c);
        System.assertEquals(null, updatedRules.get(0).RuleActions__r.get(0).Action__r.Subtype__c);
        System.assertNotEquals(defaultActions.Id, updatedRules.get(0).RuleActions__r.get(0).Action__c);

        List<Action__c> updatedActions = [SELECT Id FROM Action__c];
        System.assertEquals(2, updatedActions.size());
    }

    @IsTest
    private static void testCreateJiraRuleWithDefaultTemplate_withExistJiraTemplate() {
        Action__c defaultActions = createDefaultJiraAction();

        Map<String, Object> ruleData = new Map<String, Object> {
            'notifications' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'subType' => 'Default',
                    'type' => 'Jira Notification'
                }
            },
            'notificationsassignee' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'id' => null,
                    'monitoringruleid' => null,
                    'rulenotificationid' => null
                }
            },
            'jirarule' => new Map<String, Object> {
                'description' => 'test',
                'name' => '123123',
                'ruleEnabled' => true
            }
        };
        Map<String, Object> payload = new Map<String, Object> {
            'method' => 'setJiraRule',
            'data' => ruleData
        };

        String responseData = AdminController.remoteActionHandler(JSON.serialize(payload));
        System.assertNotEquals(null, responseData);

        List<Rule__c> rules = getRules();

        System.assertEquals(1, rules.size());
        System.assertEquals('JIRA Update', rules.get(0).Type__c);

        System.assertEquals(1, rules.get(0).RuleActions__r.size());
        System.assertEquals('Jira Notification', rules.get(0).RuleActions__r.get(0).Action__r.Action_Type__c);
        System.assertEquals('Default', rules.get(0).RuleActions__r.get(0).Action__r.Subtype__c);
        System.assertEquals(defaultActions.Id, rules.get(0).RuleActions__r.get(0).Action__c);

        List<Action__c> actions = [SELECT Id FROM Action__c];
        System.assertEquals(1, actions.size());
    }

    @IsTest
    private static void testCreateJiraRuleWithDefaultTemplate() {
        Action__c defaultActions = createDefaultJiraAction();

        Map<String, Object> ruleData = new Map<String, Object> {
            'notifications' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'subType' => 'Default',
                    'type' => 'Jira Notification'
                }
            },
            'notificationsassignee' => new List<Map<String, Object>> {
                new Map<String, Object> {
                    'id' => null,
                    'monitoringruleid' => null,
                    'rulenotificationid' => null
                }
            },
            'jirarule' => new Map<String, Object> {
                'description' => 'test',
                'name' => '123123',
                'ruleEnabled' => true
            }
        };
        Map<String, Object> payload = new Map<String, Object> {
            'method' => 'setJiraRule',
            'data' => ruleData
        };

        String responseData = AdminController.remoteActionHandler(JSON.serialize(payload));
        System.assertNotEquals(null, responseData);

        List<Rule__c> rules = getRules();
        System.assertEquals(1, rules.size());
        System.assertEquals('JIRA Update', rules.get(0).Type__c);

        System.assertEquals(1, rules.get(0).RuleActions__r.size());
        System.assertEquals('Jira Notification', rules.get(0).RuleActions__r.get(0).Action__r.Action_Type__c);
        System.assertEquals('Default', rules.get(0).RuleActions__r.get(0).Action__r.Subtype__c);

        List<Action__c> actions = [SELECT Id FROM Action__c];
        System.assertEquals(1, actions.size());
    }

    private static List<Rule__c> getRules() {
        List<Rule__c> rules = [
            SELECT Id, Type__c,
            (SELECT Id, Action__r.Type__c,
                Action__r.Action_Type__c,
                Action__r.Subtype__c,
                Action__r.Body__c,
                Action__r.CreatedDate__c,
                Action__r.Description__c,
                Action__r.EmailBody__c,
                Action__r.EmailCC__c,
                Action__r.EmailTemplateId__c,
                Action__r.EmailTo__c,
                Action__r.JIRAAssignee__c,
                Action__r.JIRAComponents__c,
                Action__r.JIRAEpic__c,
                Action__r.JIRAIssueType__c,
                Action__r.JIRALabels__c,
                Action__r.JIRAPriority__c,
                Action__r.JIRAProject__c,
                Action__r.SlackChannels__c,
                Action__r.Subject__c,
                Action__r.PagerDuty_Type__c
            FROM RuleActions__r
            )
            FROM Rule__c
        ];
        return rules;
    }

    @IsTest
    public static void testDefaultPermissions_FeatureMap1() {
        PermissionsUtil.FeatureMap1IntValue = PermissionsUtil.DEFAULT_FEATURE_MAP_1_VALUE;
        System.assertEquals(true, PermissionsUtil.MonitoringEnabled);
        System.assertEquals(true, PermissionsUtil.ArchivalEnabled);
        System.assertEquals(true, PermissionsUtil.JiraIntegrationEnabled);
        System.assertEquals(true, PermissionsUtil.SlackIntegrationEnabled);
        System.assertEquals(true, PermissionsUtil.SplunkIntegrationEnabled);
        System.assertEquals(true, PermissionsUtil.PagerDutyIntegrationEnabled);
        System.assertEquals(true, PermissionsUtil.SensitiveDataMaskingEnabled);
        System.assertEquals(true, PermissionsUtil.FlowDebugViewEnabled);
        System.assertEquals(true, PermissionsUtil.NotificationIntegrationEnabled);
        System.assertEquals(true, PermissionsUtil.NotificationIntegrationEnabled);
        System.assertEquals(true, PermissionsUtil.BulkAPITrackingEnabled);
    }

    @IsTest
    public static void testDefaultPermissions_FeatureMap2() {
        PermissionsUtil.FeatureMap2IntValue = PermissionsUtil.DEFAULT_FEATURE_MAP_2_VALUE;
        Map<Integer, Integer> maxFeatureValues = PermissionsUtil.FeatureMap2;
        System.assertEquals(255, maxFeatureValues.get(0));
        System.assertEquals(255, maxFeatureValues.get(1));
        System.assertEquals(255, maxFeatureValues.get(2));
    }

    @IsTest
    public static void testDefaultPermissions_FeatureMap3() {
        PermissionsUtil.FeatureMap3IntValue = PermissionsUtil.DEFAULT_FEATURE_MAP_3_VALUE;
        Map<Integer, Integer> maxFeatureValues = PermissionsUtil.FeatureMap3;
        System.assertEquals(255, maxFeatureValues.get(0));
        System.assertEquals(255, maxFeatureValues.get(1));
        System.assertEquals(255, maxFeatureValues.get(2));
    }

    @IsTest
    public static void testDefaultPermissions_FeatureMap4() {
        PermissionsUtil.FeatureMap4IntValue = PermissionsUtil.DEFAULT_FEATURE_MAP_4_VALUE;
        // all TTL's with DEFAULT values
        Map<Integer, Integer> featureValues = PermissionsUtil.FeatureMap4;
        SYSTEM.DEBUG(JSON.serialize(featureValues));
        System.assertEquals(0, featureValues.get(0));
        System.assertEquals(0, featureValues.get(1));
        System.assertEquals(0, featureValues.get(2));
        System.assertEquals(0, featureValues.get(3));
        System.assertEquals(0, featureValues.get(4));
        System.assertEquals(0, featureValues.get(5));
        System.assertEquals(0, featureValues.get(6));
        System.assertEquals(0, featureValues.get(7));
        System.assertEquals(5, featureValues.get(8));
    }

    @IsTest
    public static void testDefaultPermissions_FeatureMap4_max_values() {
        // all TTL's with max values
        PermissionsUtil.FeatureMap4IntValue = Integer.valueOf(Math.pow(2, 27) - 1);
        Map<Integer, Integer> featureValues = PermissionsUtil.FeatureMap4;
        System.assertEquals(7, featureValues.get(0));
        System.assertEquals(7, featureValues.get(1));
        System.assertEquals(7, featureValues.get(2));
        System.assertEquals(7, featureValues.get(3));
        System.assertEquals(7, featureValues.get(4));
        System.assertEquals(7, featureValues.get(5));
        System.assertEquals(7, featureValues.get(6));
        System.assertEquals(7, featureValues.get(7));
        System.assertEquals(7, featureValues.get(8));
    }

    @IsTest
    public static void testPermissions() {
        Integer intValue = PermissionsUtil.getIntegerFromBitmap(new Map<Integer, Integer>{
            0 => 1,
            1 => 1,
            2 => 0,
            3 => 0,
            4 => 1,
            5 => 0,
            6 => 1,
            7 => 1
        });
        PermissionsUtil.FeatureMap1IntValue = intValue;
        System.assertEquals(211, intValue);

        System.assertEquals(true, PermissionsUtil.MonitoringEnabled);
        System.assertEquals(true, PermissionsUtil.ArchivalEnabled);
        System.assertEquals(false, PermissionsUtil.JiraIntegrationEnabled);
        System.assertEquals(false, PermissionsUtil.SlackIntegrationEnabled);
        System.assertEquals(true, PermissionsUtil.SplunkIntegrationEnabled);
        System.assertEquals(false, PermissionsUtil.PagerDutyIntegrationEnabled);
        System.assertEquals(true, PermissionsUtil.SensitiveDataMaskingEnabled);
        System.assertEquals(true, PermissionsUtil.FlowDebugViewEnabled);

        Map<Integer, Integer> mapIntegers = PermissionsUtil.getBitmapFromInteger(211);
        System.assertNotEquals(null, mapIntegers);
        System.assertNotEquals(0, mapIntegers.size());

        System.assertEquals(1, mapIntegers.get(0));
        System.assertEquals(1, mapIntegers.get(1));
        System.assertEquals(0, mapIntegers.get(2));
        System.assertEquals(0, mapIntegers.get(3));
        System.assertEquals(1, mapIntegers.get(4));
        System.assertEquals(0, mapIntegers.get(5));
        System.assertEquals(1, mapIntegers.get(6));
        System.assertEquals(1, mapIntegers.get(7));
    }

    @IsTest
    static void test_getDefaultTeamsActionTemplate() {
        Map<String, String> testTemplate;
        Test.startTest();
        testTemplate = AdminService.getDefaultTeamsActionTemplate();
        Test.stopTest();
        System.assertNotEquals(null, testTemplate);
    }

    @IsTest
    static void test_getTeamsSettings() {
        AdminService.TeamsSettings settings;
        Test.startTest();
        settings = AdminService.getTeamsSettings();
        Test.stopTest();
        System.assertNotEquals(null, settings.oAuthEndpoint);
    }

    @IsTest
    static void test_getGitHubSettings() {
        AdminService.GitHubSettings settings;
        Test.startTest();
        settings = AdminService.getGitHubSettings();
        Test.stopTest();
        System.assertNotEquals(null, settings.oAuthEndpoint);
    }

    @IsTest
    static void test_setGitHubSettings() {
        AdminService.GitHubSettings settings;
        Test.startTest();
        settings = AdminService.getGitHubSettings();
        settings.enabled = true;
        AdminService.setGitHubSettings(settings);
        Test.stopTest();
        System.assertEquals(true, ConfigUtil.GIT_API_SETTINGS.Enabled__c);
    }

    @IsTest
    static void test_resetGitHubSettings() {
        AdminService.GitHubSettings settings;
        Test.startTest();
        settings = AdminService.resetGitHubSettings();
        Test.stopTest();
        System.assertEquals(false, ConfigUtil.GIT_API_SETTINGS.Enabled__c);
        System.assertEquals(null, ConfigUtil.GIT_API_SETTINGS.Token__c);
        System.assertEquals(null, ConfigUtil.GIT_API_SETTINGS.oauth_Token__c);
    }

}