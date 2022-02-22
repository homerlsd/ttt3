@IsTest
private class RuleTriggerHelperTest {

    @IsTest
    static void test_validate_monitoring_rule_on_insert_valid_case() {
        test_validate_monitoring_rule_on_insert(true, true, false);
    }
    @IsTest
    static void test_validate_monitoring_rule_on_insert_not_valid_case1() {
        test_validate_monitoring_rule_on_insert(false, false, true);
    }
    @IsTest
    static void test_validate_monitoring_rule_on_insert_not_valid_case2() {
        test_validate_monitoring_rule_on_insert(false, true, true);
    }
    @IsTest
    static void test_validate_monitoring_rule_on_insert_not_valid_case3() {
        test_validate_monitoring_rule_on_insert(true, false, true);
    }
    @IsTest
    static void test_validate_monitoring_rule_on_update_valid_case() {
        test_validate_monitoring_rule_on_update(false, true, false);
    }

    static void test_validate_monitoring_rule_on_update(Boolean isValidRule, Boolean isValidFilters, Boolean expectedResult) {
        Rule__c testRule = TestDataFactory.createMonitoringRule(isValidRule, isValidFilters);
        Test.startTest();
        TestDataFactory.setValidMonitoringRuleFields(testRule);
        update testRule;
        Test.stopTest();
        testRule = [SELECT Is_Not_Valid__c FROM Rule__c WHERE Id =: testRule.Id LIMIT 1];
        System.assertEquals(expectedResult, testRule.Is_Not_Valid__c);
    }

    static void test_validate_monitoring_rule_on_insert(Boolean isValidRule, Boolean isValidFilters, Boolean expectedResult) {
        Test.startTest();
        Rule__c testRule = TestDataFactory.createMonitoringRule(isValidRule, isValidFilters);
        Test.stopTest();
        testRule = [SELECT Is_Not_Valid__c FROM Rule__c WHERE Id =: testRule.Id LIMIT 1];
        System.assertEquals(expectedResult, testRule.Is_Not_Valid__c);
    }

    @IsTest
    static void test_validate_archival_rule_on_insert_valid_case() {
        test_validate_archival_rule_on_insert(true, true, false);
    }
    @IsTest
    static void test_validate_archival_rule_on_insert_not_valid_case1() {
        test_validate_archival_rule_on_insert(false, false, true);
    }
    @IsTest
    static void test_validate_archival_rule_on_insert_not_valid_case2() {
        test_validate_archival_rule_on_insert(false, true, true);
    }
    @IsTest
    static void test_validate_archival_rule_on_update_valid_case() {
        test_validate_archival_rule_on_update(false, true, false);
    }

    static void test_validate_archival_rule_on_update(Boolean isValidRule, Boolean isValidFilters, Boolean expectedResult) {
        Rule__c testRule = TestDataFactory.createArchivalRule(isValidRule, isValidFilters);
        Test.startTest();
        testRule.EventTimeInterval__c = 60;
        update testRule;
        Test.stopTest();
        testRule = [SELECT Is_Not_Valid__c FROM Rule__c WHERE Id =: testRule.Id LIMIT 1];
        System.assertEquals(expectedResult, testRule.Is_Not_Valid__c);
    }

    static void test_validate_archival_rule_on_insert(Boolean isValidRule, Boolean isValidFilters, Boolean expectedResult) {
        Test.startTest();
        Rule__c testRule = TestDataFactory.createArchivalRule(isValidRule, isValidFilters);
        Test.stopTest();
        testRule = [SELECT Is_Not_Valid__c FROM Rule__c WHERE Id =: testRule.Id LIMIT 1];
        System.assertEquals(expectedResult, testRule.Is_Not_Valid__c);
    }

    @IsTest
    static void test_validate_jira_rule_on_insert_valid_case() {
        test_validate_jira_rule_on_insert(true, true, false);
    }
    @IsTest
    static void test_validate_jira_rule_on_insert_not_valid_case1() {
        test_validate_jira_rule_on_insert(false, false, true);
    }
    @IsTest
    static void test_validate_jira_rule_on_insert_not_valid_case2() {
        test_validate_jira_rule_on_insert(false, true, true);
    }
    @IsTest
    static void test_validate_jira_rule_on_update_valid_case() {
        test_validate_jira_rule_on_update(false, true, false);
    }

    static void test_validate_jira_rule_on_update(Boolean isValidRule, Boolean isValidFilters, Boolean expectedResult) {
        Rule__c testRule = TestDataFactory.createJiraUpdateRule(isValidRule, isValidFilters);
        Test.startTest();
        testRule.Type__c = MonitoringUtil.RULE_TYPE_JIRA_UPDATE;
        update testRule;
        Test.stopTest();
        testRule = [SELECT Is_Not_Valid__c FROM Rule__c WHERE Id =: testRule.Id LIMIT 1];
        System.assertEquals(expectedResult, testRule.Is_Not_Valid__c);
    }

    static void test_validate_jira_rule_on_insert(Boolean isValidRule, Boolean isValidFilters, Boolean expectedResult) {
        Test.startTest();
        Rule__c testRule = TestDataFactory.createJiraUpdateRule(isValidRule, isValidFilters);
        Test.stopTest();
        testRule = [SELECT Is_Not_Valid__c FROM Rule__c WHERE Id =: testRule.Id LIMIT 1];
        System.assertEquals(expectedResult, testRule.Is_Not_Valid__c);
    }

}