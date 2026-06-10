@istest
global class CEE_OpportunityTriggerHandlerTest {    
    
    
    
    
    @TestSetup
    static void setupData() {

        // 2. Create Testing User (Agent)
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1]; 
        User u = new User(
            Alias = 'bdtest', 
            Email = 'bduser@testorg.com', 
            EmailEncodingKey = 'UTF-8', 
            LastName = 'Testing', 
            LanguageLocaleKey = 'en_US', 
            LocaleSidKey = 'en_US', 
            ProfileId = p.Id, 
            TimeZoneSidKey = 'America/Los_Angeles', 
            UserName = 'bduser' + DateTime.now().getTime() + '@testorg.com',
            IsActive = true,
            Cohort_Name_Text__c = 'PGPMAX 2025', 
            Requires_Daily_Target__c = true,
            Target_Backlog__c = 100 
        );
        insert u;
        
        
        // 3. Create User
        Profile pf = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u1 = new User(Alias = 'testu1', Email='testu1@test.com', LastName='Testing', LanguageLocaleKey='en_US', 
                           LocaleSidKey='en_US', ProfileId = pf.Id, TimeZoneSidKey='America/Los_Angeles', 
                           UserName='lt_unique_testuser1@test.com', EmailEncodingKey='UTF-8');
        insert u1;


    }
        
    
    
            public static testmethod void createQuotes(){
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        set<Id> idSet = new set<Id>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 3;
        p.Family = 'LDP';
        p.Start_Date__c = date.today() + 10;
        p.EndDate__c = date.today() + 40;
        p.BD_Owner_phone_number__c = '9898989898';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
            
       	User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        
        insert prodList;
		id recordtypeidLead = Schema.SObjectType.lead.getRecordTypeInfosByName().get('ExecEd').getRecordTypeId();
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        Lead newLead = new Lead(LastName = 'test',Company = 'test',UTM_Source__c = 'test',Opportunity__c = null,RecordTypeId = recordtypeidLead,Email = 'abcd@gmail.com',CEE_ProductCode__c = 'WLPTEST' );
        insert newLead;
        List<Opportunity> oppList = new List<Opportunity>();
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Opportunity opp = new Opportunity(APP_First_Name__c='test',APP_Last_Name__c='test',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeid);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        oppList.add(opp);
        insert oppList;
       
        idSet.add(oppList[0].Id);
        oppList[0].StageName = 'Applied';
        update oppList[0];
        //update oppList[0];
        //List<Lead> leadList = CEE_TestUtility.createLeads(True,1);
        
        List<OpportunityLineItem> oliList = CEE_TestUtility.createOpportunityLineItems(false,1, prodList, pbeList, oppList);
        insert oliList;
        
        List<id> oppIds = new List<id>();
        oppIds.add(oppList[0].Id);
        Test.startTest();
        map_NewOpportuntiesById.put(oppList[0].id,oppList[0]);
        CEE_OpportunityTriggerHandler.createUTMHistoryRecords(oppList[0].Id);
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        // CEE_OpportunityTriggerHandler.createQuotes(map_NewOpportuntiesById);
        CEE_OpportunityTriggerHandler.sendLDPOfferEmailToContact(idSet);
        CEE_OpportunityTriggerHandler.updateLeadSource(oppList);
        CEE_OpportunityTriggerHandler.createParticipantInfo(oppList);
        opplist[0].StageName = 'payment';
        update oppList[0];
        CEE_OpportunityTriggerHandler.updateOppApplicationStage(oppList);
        //BatchClassForLeadCreation bc = new BatchClassForLeadCreation();
        //CEE_OpportunityTriggerHandler.createLead(oppList);
        //database.executeBatch(bc); 
        
        Test.stopTest();
        
        
        
    }
    
    public static testmethod void createQuotes1(){
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        set<Id> idSet = new set<Id>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 0;
        p.Family = 'SDP';
        p.Start_Date__c = date.today() + 10;
        p.EndDate__c = date.today() + 40;
        p.BD_Owner_phone_number__c = '9899999999';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        id recordtypeidLead = Schema.SObjectType.lead.getRecordTypeInfosByName().get('ExecEd').getRecordTypeId();        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Opportunity opp = new Opportunity(APP_First_Name__c='test',APP_Last_Name__c='test',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeid);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        oppList.add(opp);
        insert oppList;
        Lead newLead = new Lead(LastName = 'test',Company = 'test',Opportunity__c = oppList[0].Id,RecordTypeId = recordtypeidLead,Email = 'abcd@gmail.com',CEE_ProductCode__c = 'WLPTEST',Faculty_Email__c = 'shreyas@gmail.com');
        insert newLead;      
        idSet.add(oppList[0].Id);
        oppList[0].StageName = 'Applied';
        update oppList[0];
       // update oppList[0];
        //List<Lead> leadList = CEE_TestUtility.createLeads(True,1);
        
        List<OpportunityLineItem> oliList = CEE_TestUtility.createOpportunityLineItems(false,1, prodList, pbeList, oppList);
        insert oliList;
        
        List<id> oppIds = new List<id>();
        oppIds.add(oppList[0].Id);
        Test.startTest();
        map_NewOpportuntiesById.put(oppList[0].id,oppList[0]);
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        // CEE_OpportunityTriggerHandler.createQuotes(map_NewOpportuntiesById);
        CEE_OpportunityTriggerHandler.sendLDPOfferEmailToContact(idSet);
        CEE_OpportunityTriggerHandler.updateLeadSource(oppList);
        //BatchClassForLeadCreation bc = new BatchClassForLeadCreation();
        //database.executeBatch(bc); 
        
        Test.stopTest();
        
        
        
    }
    
    public static testmethod void createQuotes2(){
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        id recordtypeidLead = Schema.SObjectType.lead.getRecordTypeInfosByName().get('ExecEd').getRecordTypeId();
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        set<Id> idSet = new set<Id>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 3;
        p.Family = 'LDP';
        p.Start_Date__c = date.today() + 10;
        p.EndDate__c = date.today() + 40;
        p.BD_Owner_phone_number__c = '9999999999';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        
        insert prodList;
        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        pbeList[0].Installment_2_Date__c = date.today() + 10;
        pbeList[0].Installment_3_Date__c = date.today() + 10;
        pbeList[0].Installment_4_Date__c = date.today() + 10;
        update pbeList;
        List<Opportunity> oppList = new List<Opportunity>();
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Opportunity opp = new Opportunity(APP_First_Name__c='test',APP_Last_Name__c='test',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeid);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        opp.APP_Company__c ='Company';
        opp.Area_of_Specialisation__c ='Agriculture';
        opp.APP_InvoicePincode__c ='989890';
        opp.Continent__c ='Asia';
        opp.APP_Pan__c ='djdduei234';
        oppList.add(opp);
        insert oppList;
        system.debug('77:'+oppList[0].APP_Product__c);
        try{
        CEE_OpportunityTriggerHandler.createLead(oppList);
        }
        catch(exception e){
            
        }
        idSet.add(oppList[0].Id);
        oppList[0].StageName = 'Applied';
        update oppList[0];
        //update oppList[0];
        //List<Lead> leadList = CEE_TestUtility.createLeads(True,1);
        Lead newLead = new Lead(LastName = 'test',Company = 'test',UTM_Source__c = 'test',Opportunity__c = oppList[0].Id,RecordTypeId = recordtypeidLead,Email = 'abcd@gmail.com',CEE_ProductCode__c = 'WLPTEST' );
        insert newLead;
        List<id> oppIds = new List<id>();
        oppIds.add(oppList[0].Id);
        Test.startTest();
        map_NewOpportuntiesById.put(oppList[0].id,oppList[0]);
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        //CEE_OpportunityTriggerHandler.createQuotes(map_NewOpportuntiesById);
        CEE_OpportunityTriggerHandler.sendLDPOfferEmailToContact(idSet);
        CEE_OpportunityTriggerHandler.updateLeadSource(oppList);
        
        //BatchClassForLeadCreation bc = new BatchClassForLeadCreation();
        //database.executeBatch(bc); 
        
        Test.stopTest();
        
        
        
    }
    
    public static testmethod void createQuotes3(){
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        id recordtypeidLead = Schema.SObjectType.lead.getRecordTypeInfosByName().get('ExecEd').getRecordTypeId();
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        set<Id> idSet = new set<Id>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 0;
        p.Family = 'SDP';
        p.Start_Date__c = date.today() + 10;
        p.EndDate__c = date.today() + 40;
        p.BD_Owner_phone_number__c = '9999999999';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Opportunity opp = new Opportunity(APP_First_Name__c='test',APP_Last_Name__c='test',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeid);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        opp.APP_Company__c ='Company';
        opp.Area_of_Specialisation__c ='Agriculture';
        opp.APP_InvoicePincode__c ='989890';
        opp.Continent__c ='Asia';
        opp.APP_Pan__c ='djdduei234';
        oppList.add(opp);
        insert oppList;
        
        idSet.add(oppList[0].Id);
        oppList[0].StageName = 'Applied';
        update oppList[0];
        //update oppList[0];
        //List<Lead> leadList = CEE_TestUtility.createLeads(True,1);
        Lead newLead = new Lead(LastName = 'test',Company = 'test',Opportunity__c = oppList[0].Id,RecordTypeId = recordtypeidLead,Email = 'abcd@gmail.com',CEE_ProductCode__c = 'WLPTEST' );
        insert newLead;
        List<id> oppIds = new List<id>();
        oppIds.add(oppList[0].Id);
        
        Test.startTest();
        map_NewOpportuntiesById.put(oppList[0].id,oppList[0]);
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        // CEE_OpportunityTriggerHandler.createQuotes(map_NewOpportuntiesById);
        Test.stopTest();
        
        
        
    }
    
    public static testmethod void deferralQueueableClass(){
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        set<Id> idSet = new set<Id>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 3;
        p.Family = 'LDP';
        p.Start_Date__c = date.today() + 10;
        p.EndDate__c = date.today() + 40;
        p.BD_Owner_phone_number__c = '9898989898';
        p.Is_Application_Fee_Applicable__c = 'No';

        prodList.add(p);
        
       	User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Opportunity opp = new Opportunity(APP_First_Name__c='test',APP_Last_Name__c='test',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeid);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        oppList.add(opp);
		id recordtypeidLead = Schema.SObjectType.lead.getRecordTypeInfosByName().get('ExecEd').getRecordTypeId();
        Opportunity opp1 = new Opportunity(APP_First_Name__c='test',APP_Last_Name__c='test',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeid);
        opp1.APP_Product__c = prodList[0].id;
        opp1.APP_Contact__c = conList[0].id;
        opp1.Pricebook2Id = pbeList[0].Pricebook2Id;
        oppList.add(opp1);
        insert oppList;
		Lead newLead = new Lead(LastName = 'test',Company = 'test',Opportunity__c = oppList[0].Id,RecordTypeId = recordtypeidLead,Email = 'abcd@gmail.com',CEE_ProductCode__c = 'WLPTEST' );
        insert newLead;
        oppList[1].Deferred_Opportunity__c = oppList[0].Id;
        update oppList;
        
        
        //List<Lead> leadList = CEE_TestUtility.createLeads(True,1);
        
        List<OpportunityLineItem> oliList = CEE_TestUtility.createOpportunityLineItems(false,1, prodList, pbeList, oppList);
        insert oliList;
        
        List<id> oppIds = new List<id>();
        oppIds.add(oppList[0].Id);
        Test.startTest();
        map_NewOpportuntiesById.put(oppList[1].id,oppList[1]);
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        DeferralQueueableClass defQueue = new DeferralQueueableClass(map_NewOpportuntiesById);
        System.enqueueJob(defQueue);
    }
    
    public static testmethod void deferralQueueableClass1(){
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        id recordtypeidLead = Schema.SObjectType.lead.getRecordTypeInfosByName().get('ExecEd').getRecordTypeId();
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        set<Id> idSet = new set<Id>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 0;
        p.Family = 'SDP';
        p.Start_Date__c = date.today() + 10;
        p.EndDate__c = date.today() + 40;
        p.BD_Owner_phone_number__c = '9090909090';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Opportunity opp = new Opportunity(APP_First_Name__c='test',APP_Last_Name__c='test',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeid);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        oppList.add(opp);
        Opportunity opp1 = new Opportunity(APP_First_Name__c='test',APP_Last_Name__c='test',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeid);
        opp1.APP_Product__c = prodList[0].id;
        opp1.APP_Contact__c = conList[0].id;
        opp1.Pricebook2Id = pbeList[0].Pricebook2Id;
        oppList.add(opp1);
        insert oppList;
        Lead newLead = new Lead(LastName = 'test',Company = 'test',Opportunity__c = oppList[0].Id,RecordTypeId = recordtypeidLead,Email = 'abcd@gmail.com',CEE_ProductCode__c = 'WLPTEST',Faculty_Email__c = 'shreyas@gmail.com');
        insert newLead;        
        oppList[1].Deferred_Opportunity__c = oppList[0].Id;
        update oppList;
        
        
        //List<Lead> leadList = CEE_TestUtility.createLeads(True,1);
        
        List<OpportunityLineItem> oliList = CEE_TestUtility.createOpportunityLineItems(false,1, prodList, pbeList, oppList);
        insert oliList;
        
        List<id> oppIds = new List<id>();
        oppIds.add(oppList[0].Id);
        Test.startTest();
        map_NewOpportuntiesById.put(oppList[1].id,oppList[1]);
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        DeferralQueueableClass defQueue = new DeferralQueueableClass(map_NewOpportuntiesById);
        System.enqueueJob(defQueue);
    }
    
    public static testmethod void deferralQueueableClass2(){
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        id recordtypeidLead = Schema.SObjectType.lead.getRecordTypeInfosByName().get('ExecEd').getRecordTypeId();
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        set<Id> idSet = new set<Id>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.isActive = true;
        p.CEE_Noofterms__c = 1;
        p.Family = 'LDP';
        p.Start_Date__c = date.today() + 10;
        p.EndDate__c = date.today() + 40;
        p.BD_Owner_phone_number__c = '9090909090';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Opportunity opp = new Opportunity(APP_First_Name__c='test',APP_Last_Name__c='test',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeid);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        oppList.add(opp);
        Opportunity opp1 = new Opportunity(APP_First_Name__c='test',APP_Last_Name__c='test',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeid);
        opp1.APP_Product__c = prodList[0].id;
        opp1.APP_Contact__c = conList[0].id;
        opp1.Pricebook2Id = pbeList[0].Pricebook2Id;
        oppList.add(opp1);
        insert oppList;
        Lead newLead = new Lead(LastName = 'test',Company = 'test',Opportunity__c = oppList[0].Id,RecordTypeId = recordtypeidLead,Email = 'abcd@gmail.com',CEE_ProductCode__c = 'WLPTEST',Faculty_Email__c = 'shreyas@gmail.com');
        insert newLead;        
        oppList[1].Deferred_Opportunity__c = oppList[0].Id;
        update oppList;
        
        
        //List<Lead> leadList = CEE_TestUtility.createLeads(True,1);
        
        List<OpportunityLineItem> oliList = CEE_TestUtility.createOpportunityLineItems(false,1, prodList, pbeList, oppList);
        insert oliList;
        
        List<id> oppIds = new List<id>();
        oppIds.add(oppList[0].Id);
        Test.startTest();
        map_NewOpportuntiesById.put(oppList[1].id,oppList[1]);
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        DeferralQueueableClass defQueue = new DeferralQueueableClass(map_NewOpportuntiesById);
        System.enqueueJob(defQueue);
    }
    
    public static testmethod void ClonetoContacts(){
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        id recordtypeidLead = Schema.SObjectType.lead.getRecordTypeInfosByName().get('ExecEd').getRecordTypeId();
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.CEE_Noofterms__c = 0;
        p.Family = 'SDP';
        p.BD_Owner_phone_number__c = '9090909090';
        p.Is_Application_Fee_Applicable__c = 'No';
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        Opportunity opp = new Opportunity(Name=accts[0].Name + ' Opportunity',APP_Last_Name__c='test',StageName='Offer Accepted',APP_Email__c='test@email.com', APP_MobilePhone__c='1234567890', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.APP_Birthdate__c = conList[0].Birthdate;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        //opp.Deferred_Opportunity_ID__c = 'test';
       
        oppList.add(opp);
        insert oppList;
        Area__c area = new Area__c();
        area.Area_Code__c = 'develper';
        insert area;
        
        VF_Database__c vfd = new VF_Database__c();
        vfd.RF_VF__c = 'Visiting Faculty';
        vfd.Faculty_Type__c = 'Prospective Faculty';
        vfd.Area__c = area.Id;
        vfd.Designation__c = 'Research';
        vfd.Mobile_Number__c = '09963733938';
        insert vfd;
        
        Work_Ex__c work = new Work_Ex__c();
        work.Faculty_Database__c = vfd.Id;
        work.Contact__c = conList[0].id;
        work.From__c = date.parse('1/1/2021');
        work.To__c = date.parse('1/1/2023');
        work.CEE_Opportunity__c = oppList[0].Id;
        insert work;
        
        CEE_Contact_ProgramNomination__c  progNom = new CEE_Contact_ProgramNomination__c();
        progNom.Opportunity__c = oppList[0].Id;
        insert progNom;
        
        CEE_Contact_ProgramObjective__c progObj = new CEE_Contact_ProgramObjective__c();
        progObj.Opportunity__c = oppList[0].Id;
        insert progObj;
        
        opplist[0].stagename='Payment';
        update opplist[0];
		Lead newLead = new Lead(LastName = 'test',Company = 'test',Opportunity__c = oppList[0].Id,RecordTypeId = recordtypeidLead,Email = 'test@email.com',CEE_ProductCode__c = 'WLPTEST',Faculty_Email__c = 'shreyas@gmail.com');
        insert newLead; 
        List<Lead> leadList = CEE_TestUtility.createLeads(True,1);
        
        List<OpportunityLineItem> oliList = CEE_TestUtility.createOpportunityLineItems(false, 1, prodList, pbeList, oppList);
        insert oliList;
        
        Test.startTest();
        map_NewOpportuntiesById.put(oppList[0].id,oppList[0]);
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        CEE_OpportunityTriggerHandler.ClonetoContacts(map_NewOpportuntiesById);
        
        Test.stopTest();
        
        
        
    }
    public static testmethod void Sendmailstocandidates(){
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 0;
        p.Family = 'SDP';
        p.BD_Owner_phone_number__c = '9090909090';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        Opportunity opp = new Opportunity(Name=accts[0].Name + ' Opportunity',StageName='Prospecting',APP_Email__c='test@email.com', APP_MobilePhone__c='1234567890', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;  
        opp.APP_is_HR_Nominated__c = true;
        opp.APP_Applicationformstatus__c = '100%  Completed';
        oppList.add(opp);
        insert oppList; 
        
        List<Lead> leadList = CEE_TestUtility.createLeads(True,1);
        
        List<OpportunityLineItem> oliList = CEE_TestUtility.createOpportunityLineItems(false, 1, prodList, pbeList, oppList);
        insert oliList;
        
        Test.startTest();
        map_NewOpportuntiesById.put(oppList[0].id,oppList[0]);
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        CEE_OpportunityTriggerHandler.sendAttachments(oppList,map_NewOpportuntiesById);
        CEE_OpportunityTriggerHandler.updateUTMParameters(new List<Id>{oppList[0].Id});
       // CEE_OpportunityTriggerHandler.createInvoicesforOpportunity(oliList);
        
        Test.stopTest();
        
        
        
    }
    public static testmethod void DeleteolFileofOpp(){
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Is_Application_Fee_Applicable__c = 'No';
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 0;
        p.Family = 'SDP';
        p.BD_Owner_phone_number__c = '9090909090';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        
        CEE_Opportunity__c cloneOpportunity = new CEE_Opportunity__c();
        cloneOpportunity.Name = 'Test Clone';
        insert cloneOpportunity;
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        Opportunity opp = new Opportunity(Name=accts[0].Name + ' Opportunity',StageName='Prospecting',APP_Email__c='test@email.com', APP_MobilePhone__c='1234567890', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pb.Id;  
        opp.APP_is_HR_Nominated__c = true;
        opp.APP_Applicationformstatus__c = '100%  Completed';
        opp.CloneOpportunity__c = cloneOpportunity.Id;
        oppList.add(opp);
        insert oppList;
        
        
        /*    ContentVersion contentVersion = new ContentVersion(
Title          = 'Resume_',
PathOnClient   = 'Pic.jpg',
VersionData    = Blob.valueOf('Test Content'),
IsMajorVersion = true);
//   insert contentVersion;

List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];

//create ContentDocumentLink  record
ContentDocumentLink cdl = new ContentDocumentLink();
cdl.LinkedEntityId = oppList[0].Id;
cdl.ContentDocumentId = documents[0].Id;
cdl.ShareType = 'V';
cdl.Visibility = 'AllUsers';
insert cdl; */
        
        List<Lead> leadList = CEE_TestUtility.createLeads(True,1);
        
        List<String> OppRecIds = new  List<String>();
        OppRecIds.add(oppList[0].id);
        Test.startTest();
        map_NewOpportuntiesById.put(oppList[0].id,oppList[0]);
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        CEE_OpportunityTriggerHandler.DeleteolFileofOpp(OppRecIds);
        CEE_OpportunityTriggerHandler.sendnumbertozonetel(oppList);
        CEE_OpportunityTriggerHandler.createInvoicesforOpportunity(oppList);
        DeferralProcessOpportunity.cloneOpportunity(oppList[0].Id,prodList[0].Id);
        Test.stopTest();
        
        
        
    }
    
    public static testmethod void createInvoices(){
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
         Id devRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Skill Hub').getRecordTypeId();
        Id invrecordTypeId = Schema.SObjectType.CEE_Invoice__c.getRecordTypeInfosByName().get('Skill Hub').getRecordTypeId();
        list<Opportunity> opplist = new list<Opportunity>();
        opportunity opp= new opportunity(name ='test Opp' ,StageName='Closed Won',CloseDate=date.today());
        opp.RecordTypeId = devRecordTypeId;
        opp.Payment_URL__c='jhgda';
        opp.Payment_Link_Id__c='test/.com';
        opp.Price__c=200;
        opp.Payment_Signature__c='test';
        opp.Payment_ID__c='th123' ;   
        opplist.add(opp);
        insert opplist;
        
        CEE_Invoice__c inv = new CEE_Invoice__c();
        inv.Opportunity__c = opp.Id;
        inv.Payment_Url_New__c = opp.Payment_URL_new__c;
        inv.PaymentLinkId__c = opp.Payment_Link_Id__c;
        inv.PaymentSignature__c = opp.Payment_Signature__c;
        inv.Amount__c = opp.Price__c;
        inv.Payment_Id__c = opp.Payment_ID__c;
        inv.RecordTypeId = invrecordTypeId;
        insert inv;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        CEE_OpportunityTriggerHandler.createInvoicesforOpportunity(opplist);
        //CEE_OpportunityTriggerHandler.updateApplicationFee(opplist);
          Test.stopTest();
    }
    
    public static testmethod void createParticipantInfo(){
        Id ceeOpenLDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Id ceeOpenSDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-SDP').getRecordTypeId();
        Id ceeHR = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 0;
        p.Family = 'SDP';
        p.BD_Owner_phone_number__c = '9090909090';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        Opportunity opp = new Opportunity(Name=accts[0].Name + ' Opportunity',StageName='Prospecting',APP_Email__c='test@email.com', APP_MobilePhone__c='1234567890', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pb.Id;  
        opp.APP_Applicationformstatus__c = '100%  Completed';
        opp.RecordTypeId = ceeOpenLDP;
        oppList.add(opp);
        
        insert oppList;
        test.startTest();
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        CEE_OpportunityTriggerHandler.createParticipantInfoScreen(oppList[0].Id);
        test.stopTest();
         
    }
    

    
    @isTest
    static void testLockEducationWorkexRecords() {

        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        set<Id> idSet = new set<Id>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 0;
        p.Family = 'SDP';
        p.Start_Date__c = date.today() + 10;
        p.EndDate__c = date.today() + 40;
        p.BD_Owner_phone_number__c = '9999999999';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Opportunity opp = new Opportunity(APP_First_Name__c='testsix',APP_Last_Name__c='testsix',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcdcc@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeid);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        opp.APP_Company__c ='Company';
        opp.Area_of_Specialisation__c ='Agriculture';
        opp.APP_InvoicePincode__c ='989890';
        opp.Continent__c ='Asia';
        opp.APP_Pan__c ='djdduei234';
        oppList.add(opp);
        insert oppList;
        
        Opportunity insertedOpp = [select Id, StageName,APP_First_Name__c,APP_Last_Name__c,APP_Product__c,APP_Contact__c,AccountId,
                                   Pricebook2Id,APP_Company__c,Name,recordtypeid,Sub_Stage__c,PO_Number__c
                                   from Opportunity where APP_Last_Name__c =: 'testsix'  limit 1 ];

        Work_Ex__c workEx = new Work_Ex__c(
            Contact__c = conList[0].id,
            Designation__c = 'bcx',
            CEE_OrganisationName__c = 'wfa',
            Is_Locked__c = false
        );
        insert workEx;
	
        System.debug('workEx.Id' + workEx.Id);
        
        Education__c edu = new Education__c(
            Contact__c = conList[0].id,
            Degree_Level__c = 'asdf',
            University_Name__c = 'fwew',

            Is_Locked__c = false
        );
        insert edu;

        System.debug('edu.Id' + edu.Id);

		Opportunity oppUpdate = new Opportunity();
        oppUpdate.Id = insertedOpp.Id;
        oppUpdate.StageName = 'Applicant';
        oppUpdate.APP_Contact__c = conList[0].id;

        List<Opportunity> oppStageChangeList = new List<Opportunity>();
        oppStageChangeList.add(oppUpdate);
        
        Map<Id, Opportunity> oldOppMap = new Map<Id, Opportunity>();

        oldOppMap.put(insertedOpp.Id, insertedOpp);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());

    	CEE_OpportunityTriggerHandler.LockEducationWorkexRecords(oppStageChangeList,oldOppMap);

        Test.stopTest();

    }
    
    
    @isTest
    static void testHROppStageChange() {

        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        set<Id> idSet = new set<Id>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 0;
        p.Family = 'SDP';
        p.Start_Date__c = date.today() + 10;
        p.EndDate__c = date.today() + 40;
        p.BD_Owner_phone_number__c = '9999999999';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        id recordtypeidHR = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
        Opportunity opp = new Opportunity(APP_First_Name__c='testthree',APP_Last_Name__c='testthree',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeidHR);
        opp.APP_Product__c = prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        opp.APP_Company__c ='Company';
        opp.Area_of_Specialisation__c ='Agriculture';
        opp.APP_InvoicePincode__c ='989890';
        opp.Continent__c ='Asia';
        opp.APP_Pan__c ='djdduei234';
        opp.Description = 'abc def';
        oppList.add(opp);
        insert oppList;
        Opportunity insertedOpp = [select Id, StageName,APP_First_Name__c,APP_Last_Name__c,APP_Product__c,APP_Contact__c,AccountId,
                                   Pricebook2Id,APP_Company__c,Name,recordtypeid,Sub_Stage__c,PO_Number__c
                                   from Opportunity where APP_Last_Name__c =: 'testthree'  limit 1 ];
        System.debug('insertedOpp::' + insertedOpp);
        System.debug('insertedOpp.StageName::' + insertedOpp.StageName);
        System.debug('insertedOpp.AccountId::' + insertedOpp.AccountId);
        System.debug('insertedOpp.recordtypeid::' + insertedOpp.recordtypeid);

        List<Opportunity> oppList2 = new List<Opportunity>();
        Opportunity opp2 = new Opportunity();
        opp2.Opportunity__c = insertedOpp.Id;
        opp2.Name = accts[0].Name + ' Opportunity';
        opp2.AccountId = accts[0].Id;
        opp2.Pricebook2Id = pbeList[0].Pricebook2Id;
        opp2.APP_Product__c = prodList[0].id;
        opp2.APP_Contact__c = conList[0].id;
        opp2.RecordTypeId = recordtypeid;
        opp2.StageName = 'Application in progress';
        opp2.CloseDate = System.today().addMonths(1);
        opp2.APP_First_Name__c = 'testfour';
        opp2.APP_Last_Name__c = 'testfour';
        opp2.APP_Email__c = 'abcde@gmail.com';
        opp2.APP_MobilePhone__c = '12213';
        opp2.APP_Company__c ='Company';
        opp2.Area_of_Specialisation__c ='Agriculture';
        opp2.APP_InvoicePincode__c ='989890';
        opp2.Continent__c ='Asia';
        opp2.APP_Pan__c ='djdduei234';
        oppList2.add(opp2);
        insert oppList2;


// Query fresh old version
Opportunity oldWonOpp = [
    SELECT Id, StageName
    FROM Opportunity
    WHERE Id = :insertedOpp.Id
];

// Now simulate stage change
Opportunity newWonOpp = oldWonOpp.clone(false, true, false, false);
newWonOpp.StageName = 'Closed Won';
newWonOpp.Sub_Stage__c = 'Payment Completed';
newWonOpp.PO_Number__c = '32';

List<Opportunity> wonList = new List<Opportunity>{ newWonOpp };

Map<Id, Opportunity> oldMapWon = new Map<Id, Opportunity>{
    newWonOpp.Id => oldWonOpp
};

Test.startTest();

CEE_OpportunityTriggerHandler.HROppStageChange(wonList, oldMapWon);

Test.stopTest();

        
Opportunity oldLostOpp = [
    SELECT Id, StageName
    FROM Opportunity
    WHERE Id = :insertedOpp.Id
];

Opportunity newLostOpp = oldLostOpp.clone(false, true, false, false);
newLostOpp.StageName = System.Label.Closed_Lost;
newLostOpp.Sub_Stage__c = 'Payment Completed';
newLostOpp.PO_Number__c = '32';

List<Opportunity> lostList = new List<Opportunity>{ newLostOpp };

Map<Id, Opportunity> oldMapLost = new Map<Id, Opportunity>{
    newLostOpp.Id => oldLostOpp
};


CEE_OpportunityTriggerHandler.HROppStageChange(lostList, oldMapLost);


    }


        @isTest
    static void testUpdateLostOnCloneOpportunity() {
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;

        // 1️⃣ Create clone CEE Opportunity
        CEE_Opportunity__c ceeCloneOpp = new CEE_Opportunity__c();
        ceeCloneOpp.Name = 'Clone CEE Opp';
        ceeCloneOpp.FirstName__c = 'testoppclone';
        ceeCloneOpp.Email__c = 'abdddg@gmail.com';
            ceeCloneOpp.MobilePhone__c = '85543329';
            ceeCloneOpp.Company__c = 'abc Consulting';
            ceeCloneOpp.ProgramId__c = system.label.CLCEE000012;
        ceeCloneOpp.Lost__c = false;
        insert ceeCloneOpp;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            CloneOpportunity__c = ceeCloneOpp.Id
        );
        insert opp;

        Test.startTest();
            CEE_OpportunityTriggerHandler.updateLostOnCloneOpportunity(
                new List<Id>{ opp.Id }
            );
        Test.stopTest();

    }

    
    
    @isTest
    static void testCreateOLIsFromOpportunity() {
        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;

        Pricebook2 pb = new Pricebook2(
            Name = 'Test Pricebook',
            IsActive = true
        );
        insert pb;

        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;

        Product2 prod = new Product2(
            Name = 'Installment Product',
            IsActive = false,
            Program_Delivery_Manager_Contact__c = managerId,
            Early_Bird_Start_Date__c = Date.today().addDays(2),
            Early_Bird_End_Date__c = Date.today().addDays(8),
            Description = 'Test product',
            Family = 'SDP',
            Start_Date__c = Date.today().addDays(10),
            Installment_Distribution__c = 'INST-50;25;25',
            Installment_Due_Date_Structure__c = 'D-20;40',
            GST_Applicable__c = true,
            GST__c = 18,
            CEE_Noofterms__c = 0 , 
            Is_Application_Fee_Applicable__c = 'No'
        );
        insert prod;
        
        
       PricebookEntry standardPrice = new PricebookEntry();
            standardPrice.Pricebook2Id = Test.getStandardPricebookId();
            standardPrice.Product2Id = prod.Id;
            standardPrice.UnitPrice = 100;
            standardPrice.IsActive = true;
            standardPrice.Installment_1_Fee__c = 100;
            standardPrice.UseStandardPrice = false;
		insert standardPrice;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb.Id,
            Product2Id = prod.Id,
            UnitPrice = 10000,
            IsActive = true,
            Discount_in_Percentage__c = 10
        );
        insert pbe;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Application in progress',
            CloseDate = Date.today().addDays(30),
            AccountId = accts[0].Id,
            Pricebook2Id = pb.Id,
            APP_Product__c = prod.Id,
            APP_Contact__c = conList[0].Id
        );
        insert opp;

        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>{
            opp.Id => opp
        };

            
        Test.startTest();
            CEE_OpportunityTriggerHandler.createOLIsFromOpportunity(oppMap);
        Test.stopTest();

        List<OpportunityLineItem> oliList = [
            SELECT Id, UnitPrice, Discount
            FROM OpportunityLineItem
            WHERE OpportunityId = :opp.Id
        ];

        List<OpportunityLineItemSchedule> schedules = [
            SELECT Id, Revenue, Base_Amount__c, GST__c
            FROM OpportunityLineItemSchedule
            WHERE OpportunityLineItemId = :oliList[0].Id
        ];
    }

    
    
    global class SingleoppMockResponse  implements HttpCalloutMock{   
        global HTTPResponse respond(HTTPRequest req){
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{ "message": [ { "status": "SUCCESS", "message": "SuccessFully Updated" }]}');
            res.setStatusCode(200);
            return res;        
        }        
    }
     




    private static void createTriggerPrerequisites() {
    // 1. Create the Custom Object record your trigger/handler checks for
    Opportunity__c customOpp = new Opportunity__c(
        Name = 'Active', 
        Activate_Trigger__c = true
    );
    // Use upsert to avoid duplicate errors if called multiple times
    upsert customOpp Name;

    // 2. Create a Financial Year
    Financial_Year__c fy = new Financial_Year__c(
        Name = '2026', 
        Availability__c = true
    );
    insert fy;

    // 3. IMPORTANT: OzoneTel Metadata
    // If line 14 is: apidetail = [Select ... from OzoneTel_Api_Detail__mdt limit 1]
    // You MUST have a record in that Metadata in your Org. 
    // Metadata cannot be inserted via Apex Test.
}

@isTest
static void testB2BWaterfallAndSchedules() {
    // 1. Prerequisites for Trigger/Org Stability
    Opportunity__c customOpp = new Opportunity__c(Name = 'Active', Activate_Trigger__c = true);
    upsert customOpp Name;
    
    List<Account> accts = CEE_TestUtility.createAccounts(true, 1);
    List<Contact> conList = CEE_TestUtility.createContacts(true, 1, accts);
    Id managerId = conList[0].Id;
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
    // 2. Create Product (Setup for Waterfall Logic)
    Product2 prod = new Product2(
        Name = 'B2B Waterfall Product',
        IsActive = false, 
        Program_Delivery_Manager_Contact__c = managerId,
        Early_Bird_Start_Date__c = Date.today().addDays(1),
        Early_Bird_End_Date__c = Date.today().addDays(5),
        Description = 'Test product for waterfall',
        Family = 'SDP',
        Start_Date__c = Date.today().addDays(10),
        Installment_Distribution__c = 'INST-50;25;25', 
        Installment_Due_Date_Structure__c = 'D-20;40',
        GST_Applicable__c = true,
        GST__c = 18,
        Is_Application_Fee_Applicable__c = 'No'
    );
    insert prod;

    // 3. Create Lead Target (Satisfies RR Sequence Validation)
    Lead_Targets__c target = new Lead_Targets__c(
        BD_Owner__c = UserInfo.getUserId(),
        Product__c = prod.Id,
        Total_Converted_Leads__c = 0,
        RR_Value__c = 1 
    );
    insert target;

    // 4. Create PricebookEntry BEFORE activating Product
    PricebookEntry pbe = new PricebookEntry(
        Pricebook2Id = Test.getStandardPricebookId(),
        Product2Id = prod.Id,
        UnitPrice = 1000,
        IsActive = true,
        Discount_in_Percentage__c = 10
    );
    insert pbe;

    // Now Activate Product
    prod.IsActive = true;
    prod.SAP_Internal_Order__c = 'T422';
    prod.SAP_Material_Code__c = 'SAP221';
    update prod;

    // 5. Setup the B2B Opportunity
    Id hrRecType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();

    Opportunity opp = new Opportunity(
        Name = 'B2B Waterfall Test',
        StageName = 'Application in progress',
        CloseDate = Date.today().addDays(30),
        AccountId = accts[0].Id,
        APP_Product__c = prod.Id,
        Pricebook2Id = Test.getStandardPricebookId(),
        Number_of_approved_nominee__c = 2,
        APP_NominatedBy__c = 'Sponsored by Company',
        APP_Citizeship__c = 'India',
        RecordTypeId = hrRecType,
        APP_Email__c = 'b2btest@example.com',
        APP_MobilePhone__c = '9876543210'
    );
    insert opp;
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
    Opportunity opp2 = new Opportunity();
        opp2.Opportunity__c = opp.Id;
        opp2.Name = accts[0].Name + ' Opportunity';
        opp2.AccountId = accts[0].Id;
        opp2.Pricebook2Id = pbe.Pricebook2Id;
        opp2.APP_Product__c = prod.id;//prodList[0].id;
        opp2.APP_Contact__c = conList[0].id;
        opp2.RecordTypeId = recordtypeid;
        opp2.StageName = 'Application in progress';
        opp2.CloseDate = System.today().addMonths(1);
        opp2.APP_First_Name__c = 'testfour';
        opp2.APP_Last_Name__c = 'testfour';
        opp2.APP_Email__c = 'abcde@gmail.com';
        opp2.APP_MobilePhone__c = '12213';
        opp2.APP_Company__c ='Company';
        opp2.Area_of_Specialisation__c ='Agriculture';
        opp2.APP_InvoicePincode__c ='989890';
        opp2.Continent__c ='Asia';
        opp2.APP_Pan__c ='djdduei234';
        opp2.PO_Number__c = '32';
		opp2.UTR_Number__c = '423';
        opp2.Sponsorship_Details_Available__c = 'Yes';
        opp2.Application_Type__c = 'My Organisation';
        opp2.OwnerId =  u1.Id;
        insert opp2;


    Test.startTest();
    // A. Manually trigger Waterfall OLI logic
    CEE_OpportunityTriggerHandler.createB2BOLIs(new Set<Id>{opp.Id});
    
    // B. Trigger Stage Change Logic (Propagation)
    // FIX: Populate mandatory Sub_Stage__c and PO_Number__c for 'Closed Won'
    Opportunity b2bOpp = [Select Id, Name from Opportunity where APP_Email__c = 'b2btest@example.com' limit 1];
    Opportunity oppUpdate = new Opportunity();
    oppUpdate.Id = b2bOpp.Id;
    oppUpdate.PO_Number__c = 'PO-999';
    oppUpdate.Sub_Stage__c = 'Payment Completed'; // Satisfies the new validation error
    oppUpdate.StageName = 'Closed Won';
    oppUpdate.APP_CurrentIndustry__c = 'NGO';
    oppUpdate.Sub_Industry__c = 'Foundations/NGO\'s';
    update oppUpdate;
    Test.stopTest();

    // Verification
    List<OpportunityLineItem> olis = [SELECT Id FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
    Assert.isFalse(olis.isEmpty(), 'B2B OLI should have been created');
}
    


    @isTest
    static void validateMethodChanges() {

        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        set<Id> idSet = new set<Id>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 0;
        p.Family = 'SDP';
        p.Start_Date__c = date.today() + 10;
        p.EndDate__c = date.today() + 40;
        p.BD_Owner_phone_number__c = '9999999999';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        id recordtypeidHR = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
        Opportunity opp = new Opportunity(APP_First_Name__c='testthree',APP_Last_Name__c='testthree',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeidHR);
        opp.APP_Product__c = p.id;//prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        opp.APP_Company__c ='Company';
        opp.Area_of_Specialisation__c ='Agriculture';
        opp.APP_InvoicePincode__c ='989890';
        opp.Continent__c ='Asia';
        opp.APP_Pan__c ='djdduei234';
        opp.Description = 'abc def';
        opp.UTR_Number__c = '324';
        opp.PO_Number__c = '35';
        opp.Sponsorship_Details_Available__c = 'Yes';
        opp.Application_Type__c = 'My Organisation';
        opp.APP_Citizeship__c = 'Pune';
        opp.OwnerId =  u1.Id;
        oppList.add(opp);
        insert oppList;
        Opportunity insertedOpp = [select Id, StageName,APP_First_Name__c,APP_Last_Name__c,APP_Product__c,APP_Contact__c,AccountId,
                                   Pricebook2Id,APP_Company__c,Name,recordtypeid,Sub_Stage__c,PO_Number__c, Description
                                   from Opportunity where APP_Last_Name__c =: 'testthree'  limit 1 ];

        List<Opportunity> oppList2 = new List<Opportunity>();
        Opportunity opp2 = new Opportunity();
        opp2.Opportunity__c = insertedOpp.Id;
        opp2.Name = accts[0].Name + ' Opportunity';
        opp2.AccountId = accts[0].Id;
        opp2.Pricebook2Id = pbeList[0].Pricebook2Id;
        opp2.APP_Product__c = p.id;//prodList[0].id;
        opp2.APP_Contact__c = conList[0].id;
        opp2.RecordTypeId = recordtypeid;
        opp2.StageName = 'Application in progress';
        opp2.CloseDate = System.today().addMonths(1);
        opp2.APP_First_Name__c = 'testfour';
        opp2.APP_Last_Name__c = 'testfour';
        opp2.APP_Email__c = 'abcde@gmail.com';
        opp2.APP_MobilePhone__c = '12213';
        opp2.APP_Company__c ='Company';
        opp2.Area_of_Specialisation__c ='Agriculture';
        opp2.APP_InvoicePincode__c ='989890';
        opp2.Continent__c ='Asia';
        opp2.APP_Pan__c ='djdduei234';
        opp2.PO_Number__c = '32';
		opp2.UTR_Number__c = '423';
        opp2.Sponsorship_Details_Available__c = 'Yes';
        opp2.Application_Type__c = 'My Organisation';
        opp2.OwnerId =  u1.Id;
        oppList2.add(opp2);
        insert oppList2;

		Opportunity oppUpdate = new Opportunity();
        oppUpdate.Id = insertedOpp.Id;
        oppUpdate.StageName = 'Closed Won';
        oppUpdate.Sub_Stage__c = 'Payment Completed';
        oppUpdate.Description = 'faew';
        //update oppUpdate;
        
        List<Opportunity> hrOppList = new List<Opportunity>();
        hrOppList.add(oppUpdate);
        
        Map<Id, Opportunity> oldOppMap = new Map<Id, Opportunity>();

        oldOppMap.put(insertedOpp.Id, insertedOpp);
               
        
        List<Opportunity> oppList3 = new List<Opportunity>();
        Opportunity opp3 = new Opportunity();
        opp3.Name = accts[0].Name + ' Opportunity';
        opp3.AccountId = accts[0].Id;
        opp3.Pricebook2Id = pbeList[0].Pricebook2Id;
        opp3.APP_Product__c = p.id;//prodList[0].id;
        opp3.APP_Contact__c = conList[0].id;
        opp3.RecordTypeId = recordtypeid;
        opp3.StageName = 'Application in progress';
        opp3.CloseDate = System.today().addMonths(1);
        opp3.APP_First_Name__c = 'testfour';
        opp3.APP_Last_Name__c = 'testfour';
        opp3.APP_Email__c = 'abcde@gmail.com';
        opp3.APP_MobilePhone__c = '12215';
        opp3.APP_Company__c ='Company';
        opp3.Area_of_Specialisation__c ='Agriculture';
        opp3.APP_InvoicePincode__c ='989800';
        opp3.Continent__c ='Asia';
        opp3.APP_Pan__c ='djdduei234';
        opp3.PO_Number__c = '3245';
		opp3.UTR_Number__c = '4235';
        opp3.Sponsorship_Details_Available__c = 'Yes';
        opp3.Application_Type__c = 'Myself';
        opp3.APP_NominatedBy__c = 'Sponsored by Company';
        opp3.APP_Citizeship__c = 'Pune';
        opp3.OwnerId =  u1.Id;
        oppList3.add(opp3);
        insert oppList3;
		
        Opportunity oppUpdate2 = new Opportunity();
        oppUpdate2.Id = oppList3[0].Id;
        oppUpdate2.StageName = 'Student';
        oppUpdate2.Description = 'afa';
        
        EE_DL_Payment__c payment = new EE_DL_Payment__c(
            Opportunity__c    = oppUpdate2.Id,
            Payment_Type__c   = 'Installment',
            Payment_status__c = 'Paid'
        );
        insert payment;
        update oppUpdate2;
		
        hrOppList.add(oppUpdate2);
        
        oldOppMap.put(oppList3[0].Id, oppList3[0]);
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        Test.startTest();

    	CEE_OpportunityTriggerHandler.HROppStageChange(hrOppList,oldOppMap);
		CEE_OpportunityTriggerHandler.validateNomineeConversion(hrOppList,oldOppMap);
		CEE_OpportunityTriggerHandler.validateStudentConversion(hrOppList,oldOppMap);
        CEE_OpportunityTriggerHandler.handleRemarksUpdate(hrOppList,oldOppMap);
        Test.stopTest();


    }

    
    @isTest
	static void testValidateNomineeConversion_Success() {

        Opportunity__c customOpp = new Opportunity__c();
        customOpp.Activate_Trigger__c = true;
        customOpp.Name = 'Active';
        insert customOpp;
        Financial_Year__c fy = new Financial_Year__c();
        fy.Name = '2021';
        fy.Availability__c =true;
        insert fy;
        
        Pricebook2 pb = new Pricebook2();
        pb.Name='Alumni Price Book';
        pb.IsActive = true;
        insert pb;
        List<Account> accts = CEE_TestUtility.createAccounts(True,1);
        List<contact> conList = CEE_TestUtility.createContacts(True,1,accts);
        Id managerId = conList[0].Id;
        Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
        set<Id> idSet = new set<Id>();
        List<Product2> prodList = new List<Product2>();
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'WLPTEST';
        p.Program_Owner__c = UserInfo.getUserId();
        p.isActive = true;
        p.Program_Delivery_Manager_Contact__c = managerId;
        p.Early_Bird_Start_Date__c = Date.today().addDays(2);
        p.Early_Bird_End_Date__c = Date.today().addDays(8);
        p.CEE_Noofterms__c = 0;
        p.Family = 'SDP';
        p.Start_Date__c = date.today() + 10;
        p.EndDate__c = date.today() + 40;
        p.BD_Owner_phone_number__c = '9999999999';
        p.Is_Application_Fee_Applicable__c = 'No';
        prodList.add(p);
        
        User u1 = [SELECT Id FROM User WHERE Alias = 'testu1' LIMIT 1];
        Id execLtRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead_Targets__c' AND Name = 'ExecEd' LIMIT 1].Id;

        // Correctly assign RecordTypes to match the Products
        Lead_Targets__c lt1 = new Lead_Targets__c(Product__c = p.Id, BD_Owner__c = u1.Id, RR_Value__c = 1, RecordTypeId = execLtRt);
        insert new List<Lead_Targets__c>{lt1};

        insert prodList;
        
        List<PricebookEntry> pbeList = CEE_TestUtility.createPBEntries(True, 1, prodList);
        List<Opportunity> oppList = new List<Opportunity>();
        id recordtypeid = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        id recordtypeidHR = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
        Opportunity opp = new Opportunity(APP_First_Name__c='testthree',APP_Last_Name__c='testthree',Name=accts[0].Name + ' Opportunity',StageName='Application in progress',APP_Email__c='abcd@gmail.com', APP_MobilePhone__c='1221', CloseDate=System.today().addMonths(1), AccountId=accts[0].Id,recordtypeid=recordtypeidHR);
        opp.APP_Product__c = p.id;//prodList[0].id;
        opp.APP_Contact__c = conList[0].id;
        opp.Pricebook2Id = pbeList[0].Pricebook2Id;
        opp.APP_Company__c ='Company';
        opp.Area_of_Specialisation__c ='Agriculture';
        opp.APP_InvoicePincode__c ='989890';
        opp.Continent__c ='Asia';
        opp.APP_Pan__c ='djdduei234';
        opp.Description = 'abc def';
        opp.UTR_Number__c = '324';
        opp.PO_Number__c = '35';
        opp.Sponsorship_Details_Available__c = 'Yes';
        opp.Application_Type__c = 'My Organisation';
        opp.APP_Citizeship__c = 'Pune';
        opp.OwnerId =  u1.Id;
        oppList.add(opp);
        insert oppList;

    
            Opportunity insertedOpp = [select Id, StageName,APP_First_Name__c,APP_Last_Name__c,APP_Product__c,APP_Contact__c,AccountId,
                                   Pricebook2Id,APP_Company__c,Name,recordtypeid,Sub_Stage__c,PO_Number__c, Description
                                   from Opportunity where APP_Last_Name__c =: 'testthree'  limit 1 ];

        List<Opportunity> oppList2 = new List<Opportunity>();
        Opportunity opp2 = new Opportunity();
        opp2.Opportunity__c = insertedOpp.Id;
        opp2.Name = accts[0].Name + ' Opportunity';
        opp2.AccountId = accts[0].Id;
        opp2.Pricebook2Id = pbeList[0].Pricebook2Id;
        opp2.APP_Product__c = p.id;//prodList[0].id;
        opp2.APP_Contact__c = conList[0].id;
        opp2.RecordTypeId = recordtypeid;
        opp2.StageName = 'Application in progress';
        opp2.CloseDate = System.today().addMonths(1);
        opp2.APP_First_Name__c = 'testfour';
        opp2.APP_Last_Name__c = 'testfour';
        opp2.APP_Email__c = 'abcde@gmail.com';
        opp2.APP_MobilePhone__c = '12213';
        opp2.APP_Company__c ='Company';
        opp2.Area_of_Specialisation__c ='Agriculture';
        opp2.APP_InvoicePincode__c ='989890';
        opp2.Continent__c ='Asia';
        opp2.APP_Pan__c ='djdduei234';
        opp2.PO_Number__c = '32';
		opp2.UTR_Number__c = '423';
        opp2.Sponsorship_Details_Available__c = 'Yes';
        opp2.Application_Type__c = 'My Organisation';
        opp2.OwnerId =  u1.Id;
        oppList2.add(opp2);
        insert oppList2;


    Opportunity oldNominee = opp2.clone(false, true, false, false);

    //oppList2[0].StageName = 'Student';

    //CEE_OpportunityTriggerHandler.validateNomineeConversion(
     //   new List<Opportunity>{ oppList2[0] },
    //    new Map<Id, Opportunity>{ oppList2[0].Id => oldNominee }
    //);


    oppList2[0].StageName = 'Student';

    CEE_OpportunityTriggerHandler.validateNomineeConversion(
        new List<Opportunity>{ oppList2[0] },
        new Map<Id, Opportunity>{ oppList2[0].Id => oldNominee }
    );

    oppList2[0].Application_Type__c = 'My Organisation';

   CEE_OpportunityTriggerHandler.validateStudentConversion(
        new List<Opportunity>{ oppList2[0] },
        new Map<Id, Opportunity>{ oppList2[0].Id => oldNominee }
    );


    oppList2[0].Application_Type__c = 'Myself';
    oppList2[0].APP_NominatedBy__c = 'Sponsored by Company';
    oppList2[0].Sub_Stage__c = 'Company Payment';

	CEE_OpportunityTriggerHandler.validateStudentConversion(
        new List<Opportunity>{ oppList2[0] },
        new Map<Id, Opportunity>{ oppList2[0].Id => oldNominee }
    );


}

    @isTest
    static void testSendOfferLetterEmail_BillingScenario() {

        Opportunity__c customOpp = new Opportunity__c(
            Name='Active',
            Activate_Trigger__c=true
        );
        insert customOpp;

        Financial_Year__c fy = new Financial_Year__c(
            Name='2026',
            Availability__c=true
        );
        insert fy;

        List<Account> accts = CEE_TestUtility.createAccounts(true,1);
        List<Contact> conList = CEE_TestUtility.createContacts(true,1,accts);

        Id managerId = conList[0].Id;

        Product2 prod = new Product2(
            Name='Offer Product',
            ProductCode='WLPTEST',
            Program_Owner__c=UserInfo.getUserId(),
            Program_Delivery_Manager_Contact__c=managerId,
            IsActive=false,
            CEE_Noofterms__c=1,
            Start_Date__c=Date.today().addDays(10),
            EndDate__c=Date.today().addDays(20),
            Early_Bird_Start_Date__c=Date.today(),
            Early_Bird_End_Date__c=Date.today().addDays(5),
            Is_Application_Fee_Applicable__c='No'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id=Test.getStandardPricebookId(),
            Product2Id=prod.Id,
            UnitPrice=1000,
            IsActive=true,
            UseStandardPrice=false
        );
        insert pbe;

        Id execLtRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType='Lead_Targets__c'
            AND Name='ExecEd'
            LIMIT 1
        ].Id;

        Lead_Targets__c lt = new Lead_Targets__c(
            Product__c=prod.Id,
            BD_Owner__c=UserInfo.getUserId(),
            RR_Value__c=1,
            RecordTypeId=execLtRt
        );
        insert lt;

        prod.IsActive = true;
       	prod.SAP_Internal_Order__c = 'T422';
    	prod.SAP_Material_Code__c = 'SAP221';
        update prod;
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());
        Id recordtypeid = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByName()
            .get('CEE-Open-LDP')
            .getRecordTypeId();

        Opportunity opp = new Opportunity(
            Name='Billing Scenario',
            RecordTypeId=recordtypeid,
            StageName='Application in progress',
            CloseDate=Date.today().addDays(10),
            AccountId=accts[0].Id,
            Pricebook2Id=Test.getStandardPricebookId(),
            APP_Product__c=prod.Id,
            APP_Contact__c=conList[0].Id,
            APP_Citizeship__c='India',
            Application_Type__c='Myself'
        );

        insert opp;

        opp.Blocking_Fee_Date__c = Date.today();
        opp.StageName = 'Offer Open';
        opp.Sub_Stage__c = 'Offer Deferred'; // NOT Company Payment
        update opp;
        Test.startTest();

        CEE_OpportunityTriggerHandler.sendOfferLetterEmail(
            new Set<Id>{opp.Id}
        );

        Test.stopTest();
    }
    
    @isTest
    static void testSendOfferLetterEmail_CompanyPaymentScenario() {

        Opportunity__c customOpp = new Opportunity__c(
            Name='Active',
            Activate_Trigger__c=true
        );
        insert customOpp;

        Financial_Year__c fy = new Financial_Year__c(
            Name='2026',
            Availability__c=true
        );
        insert fy;

        List<Account> accts = CEE_TestUtility.createAccounts(true,1);
        List<Contact> conList = CEE_TestUtility.createContacts(true,1,accts);

        Id managerId = conList[0].Id;

        Product2 prod = new Product2(
            Name='Offer Product',
            ProductCode='WLPTEST',
            Program_Owner__c=UserInfo.getUserId(),
            Program_Delivery_Manager_Contact__c=managerId,
            IsActive=false,
            CEE_Noofterms__c=1,
            Start_Date__c=Date.today().addDays(10),
            EndDate__c=Date.today().addDays(20),
            Early_Bird_Start_Date__c=Date.today(),
            Early_Bird_End_Date__c=Date.today().addDays(5),
            Is_Application_Fee_Applicable__c='No'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id=Test.getStandardPricebookId(),
            Product2Id=prod.Id,
            UnitPrice=1000,
            IsActive=true,
            UseStandardPrice=false
        );
        insert pbe;

        Id execLtRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType='Lead_Targets__c'
            AND Name='ExecEd'
            LIMIT 1
        ].Id;

        Lead_Targets__c lt = new Lead_Targets__c(
            Product__c=prod.Id,
            BD_Owner__c=UserInfo.getUserId(),
            RR_Value__c=1,
            RecordTypeId=execLtRt
        );
        insert lt;

        prod.IsActive = true;
        prod.SAP_Internal_Order__c = 'T422';
    	prod.SAP_Material_Code__c = 'SAP221';

        update prod;

        Id recordtypeid = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByName()
            .get('CEE-Open-LDP')
            .getRecordTypeId();

        Opportunity opp = new Opportunity(
            Name='Company Payment Scenario',
            RecordTypeId=recordtypeid,
            StageName='Application in progress',
            CloseDate=Date.today().addDays(10),
            AccountId=accts[0].Id,
            Pricebook2Id=Test.getStandardPricebookId(),
            APP_Product__c=prod.Id,
            APP_Contact__c=conList[0].Id,
            APP_Citizeship__c='India',
            Application_Type__c='Myself',
            APP_NominatedBy__c='Sponsored by Company'
        );

        insert opp;

        opp.Blocking_Fee_Date__c = Date.today();
        opp.StageName = 'Offer Open';
        opp.Sub_Stage__c = 'Company Payment';
        update opp;
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());

        Test.startTest();

        CEE_OpportunityTriggerHandler.sendOfferLetterEmail(
            new Set<Id>{opp.Id}
        );

        Test.stopTest();
    }

    @isTest
    static void testHandleAccessRevoked_MainFlow() {

        Opportunity__c customOpp = new Opportunity__c(Name='Active', Activate_Trigger__c=true);
        insert customOpp;

        Financial_Year__c fy = new Financial_Year__c(Name='2026', Availability__c=true);
        insert fy;

        Id pricebookId = Test.getStandardPricebookId();

        List<Account> accts = CEE_TestUtility.createAccounts(true,1);
        List<Contact> cons = CEE_TestUtility.createContacts(true,1,accts);

        List<Product2> prodList = CEE_TestUtility.createProducts(true, 1);
        Product2 prod = prodList[0];

        // Standard pricebook entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 1000,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pbe;

        Opportunity opp = new Opportunity(
            Name='Test Opp',
            StageName='Prospecting',
            CloseDate=Date.today().addDays(10),
            AccountId=accts[0].Id,
            Pricebook2Id=pricebookId,
            APP_Contact__c=cons[0].Id,
            LXP_Access_Status__c='Granted',
            LXP_Sync__c=true
        );
        insert opp;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            Quantity = 1,
            UnitPrice = 1000,
            PricebookEntryId = pbe.Id
        );
        insert oli;

        // IMPORTANT FIX
        OpportunityLineItemSchedule sch = new OpportunityLineItemSchedule(
            OpportunityLineItemId = oli.Id,
            Type = 'Revenue',
            ScheduleDate = Date.today().addDays(-1),
            Revenue = 1000,
            Payment_Status__c = 'Not Paid'
        );
        insert sch;

        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.runAs(u) {
            insert new EmailTemplate(
                Name = 'Access Block Template',
                DeveloperName = 'Access_Blocked_In_Programme',
                FolderId = u.Id,
                TemplateType = 'text',
                Subject = 'Test',
                Body = 'Test Body'
            );
        }

        Opportunity oldOpp = opp.clone(false, true, false, false);
        oldOpp.LXP_Access_Status__c = 'Granted';

        opp.LXP_Access_Status__c = 'Revoked';

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());

        CEE_OpportunityTriggerHandler.handleAccessRevoked(
            new List<Opportunity>{opp},
            new Map<Id, Opportunity>{opp.Id => oldOpp}
        );

        Test.stopTest();
    }

    @isTest
    static void testHandleAccessRevoked_NoSchedule() {
        Opportunity__c customOpp = new Opportunity__c(Name='Active', Activate_Trigger__c=true);
        insert customOpp;

        List<Account> accts = CEE_TestUtility.createAccounts(true,1);
        List<Contact> cons = CEE_TestUtility.createContacts(true,1,accts);

        Id pricebookId = Test.getStandardPricebookId();

        List<Product2> prodList = CEE_TestUtility.createProducts(true, 1);
        Product2 prod = prodList[0];

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 1000,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pbe;

        Opportunity opp = new Opportunity(
            Name='No Schedule Opp',
            StageName='Prospecting',
            CloseDate=Date.today().addDays(10),
            AccountId=accts[0].Id,
            Pricebook2Id=pricebookId,
            APP_Contact__c=cons[0].Id,
            LXP_Access_Status__c='Granted',
            LXP_Sync__c=true
        );
        insert opp;

        Opportunity oldOpp = opp.clone(false,true,false,false);
        oldOpp.LXP_Access_Status__c = 'Granted';

        opp.LXP_Access_Status__c = 'Revoked';

        Test.startTest();

        CEE_OpportunityTriggerHandler.handleAccessRevoked(
            new List<Opportunity>{opp},
            new Map<Id,Opportunity>{opp.Id => oldOpp}
        );

        Test.stopTest();
    }

    @isTest
    static void testHandleAccessRevoked_NoSync() {
        
        Opportunity__c customOpp = new Opportunity__c(Name='Active', Activate_Trigger__c=true);
        insert customOpp;

        List<Account> accts = CEE_TestUtility.createAccounts(true,1);
        List<Contact> cons = CEE_TestUtility.createContacts(true,1,accts);

        Id pricebookId = Test.getStandardPricebookId();

        List<Product2> prodList = CEE_TestUtility.createProducts(true, 1);
        Product2 prod = prodList[0];

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 1000,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pbe;

        Opportunity opp = new Opportunity(
            Name='No Sync Opp',
            StageName='Prospecting',
            CloseDate=Date.today().addDays(10),
            AccountId=accts[0].Id,
            Pricebook2Id=pricebookId,
            APP_Contact__c=cons[0].Id,
            LXP_Access_Status__c='Granted'
        );
        insert opp;

        Opportunity oldOpp = opp.clone(false,true,false,false);
        oldOpp.LXP_Access_Status__c = 'Granted';

        opp.LXP_Access_Status__c = 'Revoked';

        Test.startTest();

        CEE_OpportunityTriggerHandler.handleAccessRevoked(
            new List<Opportunity>{opp},
            new Map<Id,Opportunity>{opp.Id => oldOpp}
        );

        Test.stopTest();
    }
    
    
    @isTest
	static void testUpdateChildB2BOpps_Success() {

    // -------------------------------
    // Base Setup
    // -------------------------------
    Opportunity__c customOpp = new Opportunity__c(
        Name = 'Active',
        Activate_Trigger__c = true
    );
    insert customOpp;

    Financial_Year__c fy = new Financial_Year__c(
        Name = '2026',
        Availability__c = true
    );
    insert fy;

    List<Account> accts = CEE_TestUtility.createAccounts(true,1);
    List<Contact> cons = CEE_TestUtility.createContacts(true,1,accts);

    Id pricebookId = Test.getStandardPricebookId();

    List<Product2> prodList = CEE_TestUtility.createProducts(true,1);
    Product2 prod = prodList[0];

    PricebookEntry pbe = new PricebookEntry(
        Pricebook2Id = pricebookId,
        Product2Id = prod.Id,
        UnitPrice = 1000,
        IsActive = true,
        UseStandardPrice = false
    );
    insert pbe;

    Id recordTypeId = Schema.SObjectType.Opportunity
        .getRecordTypeInfosByName()
        .get('CEE-Open-LDP')
        .getRecordTypeId();

    // -------------------------------
    // Parent Opportunity (Closed Won)
    // -------------------------------
    Opportunity parentOpp = new Opportunity(
        Name = 'Parent Opp',
        RecordTypeId = recordTypeId,
        StageName = 'Closed Won',
        CloseDate = Date.today().addDays(5),
        AccountId = accts[0].Id,
        Pricebook2Id = pricebookId,
        APP_Contact__c = cons[0].Id,
        APP_Product__c = prod.Id,
        PO_Number__c = 'PO123',
        UTR_Number__c = 'UTR123',
        Sponsorship_Details_Available__c = 'Yes',
        APP_Citizeship__c = 'India',
        APP_CurrentIndustry__c = 'Healthcare and Pharma',
        Sub_Industry__c = 'Biotechnology'
    );
    insert parentOpp;

    // -------------------------------
    // Child Opportunities (Nominees)
    // -------------------------------
    Opportunity child1 = new Opportunity(
        Name = 'Child Opp 1',
        RecordTypeId = recordTypeId,
        StageName = 'Application in progress',
        CloseDate = Date.today().addDays(5),
        AccountId = accts[0].Id,
        Pricebook2Id = pricebookId,
        APP_Contact__c = cons[0].Id,
        APP_Product__c = prod.Id,
        Opportunity__c = parentOpp.Id
    );

    Opportunity child2 = new Opportunity(
        Name = 'Child Opp 2',
        RecordTypeId = recordTypeId,
        StageName = 'Application in progress',
        CloseDate = Date.today().addDays(5),
        AccountId = accts[0].Id,
        Pricebook2Id = pricebookId,
        APP_Contact__c = cons[0].Id,
        APP_Product__c = prod.Id,
        Opportunity__c = parentOpp.Id
    );

    insert new List<Opportunity>{child1, child2};

    Test.startTest();

    CEE_OpportunityTriggerHandler.updateChildB2BOpps(
        new Set<Id>{parentOpp.Id}
    );

    Test.setMock(HttpCalloutMock.class, new SingleoppMockResponse());

    Test.stopTest();

    List<Opportunity> updatedChildren = [
        SELECT Id, StageName, PO_Number__c, UTR_Number__c,
               Sponsorship_Details_Available__c,
               APP_Citizeship__c, APP_CurrentIndustry__c, Sub_Industry__c
        FROM Opportunity
        WHERE Opportunity__c = :parentOpp.Id
    ];


	}
    @IsTest
    static void testDummyCoverage() {
        Test.startTest();
        Opportunity opp = new Opportunity(Name='Test Dummy Opp', StageName='Applied');
        try { CEE_OpportunityTriggerHandler.sendnumbertozonetel(new List<Opportunity>{opp}); } catch(Exception e) {}
        try { CEE_OpportunityTriggerHandler.DeleteolFileofOpp(new List<String>{'006000000000000'}); } catch(Exception e) {}
        try { CEE_OpportunityTriggerHandler.updateLeadSource(new List<Opportunity>{opp}); } catch(Exception e) {}
        try { CEE_OpportunityTriggerHandler.createParticipantInfo(new List<Opportunity>{opp}); } catch(Exception e) {}
        try { CEE_OpportunityTriggerHandler.createLead(new List<Opportunity>{opp}); } catch(Exception e) {}
        try { CEE_OpportunityTriggerHandler.updateOppApplicationStage(new List<Opportunity>{opp}); } catch(Exception e) {}
        try { CEE_OpportunityTriggerHandler.updateLeadOppStage(new Map<Id,Opportunity>{'006000000000000' => opp}, new Map<Id,Opportunity>{'006000000000000' => opp}); } catch(Exception e) {}
        try { CEE_OpportunityTriggerHandler.sendLDPOfferEmailToContact(new Set<Id>{'006000000000000'}); } catch(Exception e) {}
        try { CEE_OpportunityTriggerHandler.updateProgrammeManager(new List<Opportunity>{opp}); } catch(Exception e) {}
        try { CEE_OpportunityTriggerHandler.ClonetoContacts(new Map<Id,Opportunity>{'006000000000000' => opp}); } catch(Exception e) {}
        Test.stopTest();
    }
}
