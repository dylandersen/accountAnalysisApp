@isTest
private class AccountRelationshipHealthControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Health Account'
        );
        insert testAccount;
        
        // Create test contacts
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'test@example.com'
        );
        insert testContact;
        
        // Create test opportunities
        List<Opportunity> opps = new List<Opportunity>();
        opps.add(new Opportunity(
            Name = 'Test Opp 1',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 100000
        ));
        opps.add(new Opportunity(
            Name = 'Test Opp 2',
            AccountId = testAccount.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(-10),
            Amount = 50000
        ));
        insert opps;
        
        // Create test cases
        List<Case> cases = new List<Case>();
        cases.add(new Case(
            AccountId = testAccount.Id,
            Subject = 'Test Case 1',
            Status = 'New',
            Priority = 'High'
        ));
        cases.add(new Case(
            AccountId = testAccount.Id,
            Subject = 'Test Case 2',
            Status = 'Closed',
            Priority = 'Medium'
        ));
        insert cases;
        
        // Create test tasks
        List<Task> tasks = new List<Task>();
        tasks.add(new Task(
            WhatId = testAccount.Id,
            Subject = 'Follow up call',
            Status = 'Completed',
            CallType = 'Outbound',
            CallDurationInSeconds = 600
        ));
        tasks.add(new Task(
            WhatId = testAccount.Id,
            Subject = 'Send proposal',
            Status = 'Completed'
        ));
        insert tasks;
        
        // Create test events
        List<Event> events = new List<Event>();
        events.add(new Event(
            WhatId = testAccount.Id,
            Subject = 'Demo Meeting',
            StartDateTime = DateTime.now().addDays(-5),
            EndDateTime = DateTime.now().addDays(-5).addHours(1),
            DurationInMinutes = 60
        ));
        insert events;
    }
    
    @isTest
    static void testGetRelationshipHealthWithData() {
        // Get test account
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Health Account' LIMIT 1];
        
        Test.startTest();
        AccountHealthAnalysis analysis = AccountRelationshipHealthController.getRelationshipHealth(testAccount.Id);
        Test.stopTest();
        
        // Verify metrics were gathered
        System.assertNotEquals(null, analysis, 'Analysis should not be null');
        System.assertNotEquals(null, analysis.metrics, 'Metrics should not be null');
        
        // Verify opportunity metrics
        System.assertEquals(2, analysis.metrics.oppCount, 'Should have 2 opportunities');
        System.assertEquals(1, analysis.metrics.activeOpps, 'Should have 1 active opportunity');
        System.assertEquals(1, analysis.metrics.wonOpps, 'Should have 1 won opportunity');
        
        // Verify case metrics
        System.assertEquals(2, analysis.metrics.caseCount, 'Should have 2 cases');
        
        // Verify task metrics
        System.assertEquals(2, analysis.metrics.taskCount, 'Should have 2 tasks');
        System.assertEquals(1, analysis.metrics.callCount, 'Should have 1 call');
        
        // Verify event metrics
        System.assertEquals(1, analysis.metrics.eventCount, 'Should have 1 event');
        
        // Verify analysis has required fields
        System.assertNotEquals(null, analysis.healthStatus, 'Health status should not be null');
        System.assertNotEquals(null, analysis.score, 'Score should not be null');
        System.assertNotEquals(null, analysis.trend, 'Trend should not be null');
        System.assertNotEquals(null, analysis.keyInsights, 'Key insights should not be null');
        System.assertNotEquals(null, analysis.recommendedActions, 'Recommended actions should not be null');
    }
    
    @isTest
    static void testGetRelationshipHealthWithMinimalData() {
        // Create account with no related data
        Account emptyAccount = new Account(Name = 'Empty Account');
        insert emptyAccount;
        
        Test.startTest();
        AccountHealthAnalysis analysis = AccountRelationshipHealthController.getRelationshipHealth(emptyAccount.Id);
        Test.stopTest();
        
        // Verify metrics are zero
        System.assertEquals(0, analysis.metrics.emailCount, 'Email count should be 0');
        System.assertEquals(0, analysis.metrics.taskCount, 'Task count should be 0');
        System.assertEquals(0, analysis.metrics.eventCount, 'Event count should be 0');
        System.assertEquals(0, analysis.metrics.caseCount, 'Case count should be 0');
        System.assertEquals(0, analysis.metrics.oppCount, 'Opportunity count should be 0');
        System.assertEquals(0, analysis.metrics.chatterCount, 'Chatter count should be 0');
        
        // Verify analysis still returns valid structure
        System.assertNotEquals(null, analysis.healthStatus, 'Health status should not be null');
        System.assertNotEquals(null, analysis.keyInsights, 'Key insights should not be null');
    }
    
    @isTest
    static void testGetRelationshipHealthWithInvalidId() {
        // Test with null ID
        Test.startTest();
        AccountHealthAnalysis analysis = AccountRelationshipHealthController.getRelationshipHealth(null);
        Test.stopTest();
        
        // Should handle gracefully and return error
        System.assertNotEquals(null, analysis, 'Analysis should not be null');
        System.assertNotEquals(null, analysis.errorMessage, 'Error message should be set');
    }
    
    @isTest
    static void testMetricsCalculation() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Health Account' LIMIT 1];
        
        // Add more tasks with call duration
        List<Task> moreTasks = new List<Task>();
        moreTasks.add(new Task(
            WhatId = testAccount.Id,
            Subject = 'Call customer',
            Status = 'Completed',
            CallType = 'Inbound',
            CallDurationInSeconds = 900
        ));
        moreTasks.add(new Task(
            WhatId = testAccount.Id,
            Subject = 'Phone call',
            Status = 'Completed',
            CallType = 'Outbound',
            CallDurationInSeconds = 1200
        ));
        insert moreTasks;
        
        Test.startTest();
        AccountHealthAnalysis analysis = AccountRelationshipHealthController.getRelationshipHealth(testAccount.Id);
        Test.stopTest();
        
        // Verify call metrics
        System.assertEquals(3, analysis.metrics.callCount, 'Should have 3 calls total');
        System.assert(analysis.metrics.avgCallDuration > 0, 'Average call duration should be greater than 0');
    }
    
    @isTest
    static void testCasePriorityMetrics() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Health Account' LIMIT 1];
        
        // Add high priority cases
        List<Case> highPriorityCases = new List<Case>();
        highPriorityCases.add(new Case(
            AccountId = testAccount.Id,
            Subject = 'Urgent Issue',
            Status = 'New',
            Priority = 'Urgent'
        ));
        highPriorityCases.add(new Case(
            AccountId = testAccount.Id,
            Subject = 'High Priority Issue',
            Status = 'Working',
            Priority = 'High'
        ));
        insert highPriorityCases;
        
        Test.startTest();
        AccountHealthAnalysis analysis = AccountRelationshipHealthController.getRelationshipHealth(testAccount.Id);
        Test.stopTest();
        
        // Verify escalated cases count
        System.assert(analysis.metrics.escalatedCases >= 2, 'Should have at least 2 escalated cases');
        System.assert(analysis.metrics.openCases >= 2, 'Should have at least 2 open cases');
    }
    
    @isTest
    static void testHealthAnalysisStructure() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Health Account' LIMIT 1];
        
        Test.startTest();
        AccountHealthAnalysis analysis = AccountRelationshipHealthController.getRelationshipHealth(testAccount.Id);
        Test.stopTest();
        
        // Verify all required fields are present
        System.assertNotEquals(null, analysis.healthStatus, 'healthStatus should exist');
        System.assertNotEquals(null, analysis.score, 'score should exist');
        System.assertNotEquals(null, analysis.trend, 'trend should exist');
        System.assertNotEquals(null, analysis.keyInsights, 'keyInsights should exist');
        System.assertNotEquals(null, analysis.recommendedActions, 'recommendedActions should exist');
        System.assertNotEquals(null, analysis.metrics, 'metrics should exist');
        
        // Verify score is in valid range
        System.assert(analysis.score >= 0, 'Score should be >= 0');
        System.assert(analysis.score <= 100, 'Score should be <= 100');
    }
}

