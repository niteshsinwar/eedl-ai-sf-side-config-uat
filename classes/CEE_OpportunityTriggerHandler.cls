/*******************************************************************************************************
* 
* @name         :    CEE_OpportunityTriggerHandler
* @author       :    Pavan Kumars
* @date         :    02-12-2021
* @description  :    Controller for Opportunity object
* @test classes :    
*
*   Date            |  Developer Name                       |  Version      |  Changes
* ======================================================================================================
*   01-11-2021      |  pavankumar.gudavalli@absyz.com       |  1.0          |  Initial Version
*   22-12-2021      |  vipeen.sarode@absyz.com              |  1.0          |  Added Close lead functionality on opportunity creation
*******************************************************************************************************/

public class CEE_OpportunityTriggerHandler {
    /**
* @author      :    Pavan Kumar
* @description :    To create quote when opportunity stage changes to
* @param       :    list_Opportunties - records to create quotes from
* @return      :    void
**/
    
    Public static Boolean skipAfterUpdate=True;
    Public static Boolean skipBeforeUpdate=True;
    public static boolean flag = true;
    public static Boolean isInsertingOpportunityId = false;
    
    
    @future
    public static void updateLostOnCloneOpportunity(List<Id> oppIds){
        List<String> cloneOppIds = new List<String>();
        List<Opportunity> getOpportunity = [Select Id,CloneOpportunity__c from Opportunity where Id IN :oppIds];
        for(Opportunity opp:getOpportunity){
            cloneOppIds.add(opp.CloneOpportunity__c);
        }
        List<CEE_Opportunity__c> cloneOpportunity = [Select Id,Lost__c from CEE_Opportunity__c where ID IN :cloneOppIds];
        for(CEE_Opportunity__c ceeOpp:cloneOpportunity){
            ceeOpp.Lost__c = true;
        }
        update cloneOpportunity;
    }
    
    public static void insertOpportunityId(List<Opportunity> oppList){
        List<Opportunity> updateOpportunity = new List<Opportunity>();
        for(Opportunity opp:oppList){
            Opportunity updateOpp = new Opportunity();
            updateOpp.Id = opp.Id;
            updateOpp.Opportunity_Record_Id__c = opp.Id;
            updateOpportunity.add(updateOpp);
        }
        isInsertingOpportunityId = true;
        update updateOpportunity;
        isInsertingOpportunityId = false;
    }
    
    /*public static void createQuotes(Map<Id,Opportunity> map_NewOpportuntiesById) {
        system.debug('11:called');
        List<OpportunityLineItem> list_OpportunityLineItems = new List<OpportunityLineItem>();
        try{
            for(Opportunity curoppObj:map_NewOpportuntiesById.values()){
                List<OpportunityLineItem> existingLineItems = [Select Id from OpportunityLineItem where OpportunityId = :curoppObj.Id];
                if(existingLineItems.size() == 0){
                    
                    String strProductId = curoppObj.APP_Product__c;
                    // 
                    String strcontactId = curoppObj.APP_Contact__c;
                    //  
                    String PricebookId =  curoppObj.Pricebook2Id;
                    system.debug('Price Book Id'+PricebookId);
                    Contact contactObj = new contact();
                    Boolean Applydiscount = false;
                    if(strcontactId != null && strcontactId!=''){
                        contactObj = [Select Id,AccountId, Prefix__c,Alumni__c,Student__c,Associate_Alumni__c,Associate_Student__c, FirstName, LastName, MiddleName, Email, Birthdate, hed__Gender__c, hed__Citizenship__c,CEE_ContactType__c from Contact where id=:strcontactId];
                    }
                    Product2 objSelectedProduct = [SELECT id,
                                                   Name,
                                                   Family,
                                                   CEE_Noofterms__c,
                                                   
                                                   EndDate__c,
                                                   Start_Date__c,
                                                   Description
                                                   FROM Product2 
                                                   WHERE id=:strProductId];
                    PricebookEntry objPriceEntry = new PricebookEntry();
                    List<PricebookEntry> objPriceEntrys = [SELECT 
                                                           Installment_1_Date__c,
                                                           Installment_2_Date__c,
                                                           Installment_3_Date__c,
                                                           Installment_4_Date__c,
                                                           Installment_1_Fee__c,
                                                           Installment_1_Fee_Including_18_GST__c,
                                                           Installment_2_Fee_Including_18_GST__c,
                                                           Installment_3_Fee_Including_18_GST__c,
                                                           Installment_4_Fee_Including_18_GST__c,
                                                           Installment_2_Fee__c,
                                                           Installment_3_Fee__c,
                                                           Installment_4_Fee__c,
                                                           Pricebook2.Name
                                                           FROM PricebookEntry
                                                           WHERE Product2Id=:strProductId
                                                           AND Pricebook2Id=:PricebookId];
                    system.debug('Pricebook entry'+objPriceEntrys);
                    
                    if(objPriceEntrys.size()==0){
                        system.debug('inside error');
                        //   curoppObj.addError('Prices not available with selected price book');
                        //CalloutException e = new CalloutException();
                        //e.setMessage('This is a constructed exception!');
                        //throw e;
                        // throw new AuraHandledException('Your Custom Message Here');
                    }    
                    if(objPriceEntrys.size()>0){
                        objPriceEntry = objPriceEntrys[0];
                    }
                    
                    System.debug(objSelectedProduct.Family);
                    if(objSelectedProduct.Family == 'LDP'  ){
                        for(Integer termvar = 1;termvar<=objSelectedProduct.CEE_Noofterms__c;termvar++){
                            
                            OpportunityLineItem objOLI = new OpportunityLineItem();
                            objOLI.Product2Id = objSelectedProduct.Id;
                            objOLI.Quantity = 1 ;
                            objOLI.OpportunityId = curoppObj.Id;
                            objOLI.Description = objSelectedProduct.Description;
                            objOLI.CEE_Term__c = termvar;
                            objOLI.CEE_ContactEmail__c = contactObj.Email;
                            objOLI.CEE_PaymentStatus__c = 'Not Paid';
                            
                            
                            if(termvar==1){
                                
                                
                                
                                objOLI.CEE_TermStartDate__c = objPriceEntry.Installment_1_Date__c;
                                objOLI.UnitPrice = objPriceEntry.Installment_1_Fee_Including_18_GST__c;
                                if(objPriceEntry.Installment_2_Date__c!=null){
                                    objOLI.CEE_TermEndDate__c = (objPriceEntry.Installment_2_Date__c-1);
                                    
                                    
                                }
                            }
                            else if(termvar==2){
                                objOLI.CEE_TermStartDate__c = objPriceEntry.Installment_2_Date__c;
                                objOLI.UnitPrice = objPriceEntry.Installment_2_Fee_Including_18_GST__c;
                                if(objPriceEntry.Installment_3_Date__c!=null){
                                    objOLI.CEE_TermEndDate__c = (objPriceEntry.Installment_3_Date__c-1);
                                    
                                }
                            }
                            else if(termvar==3){
                                objOLI.CEE_TermStartDate__c = objPriceEntry.Installment_3_Date__c;
                                objOLI.UnitPrice = objPriceEntry.Installment_3_Fee_Including_18_GST__c;
                                if(objPriceEntry.Installment_4_Date__c!=null){
                                    objOLI.CEE_TermEndDate__c = (objPriceEntry.Installment_4_Date__c-1);
                                    
                                }
                            }
                            else if(termvar==4){
                                objOLI.CEE_TermStartDate__c = objPriceEntry.Installment_4_Date__c;
                                objOLI.UnitPrice = objPriceEntry.Installment_4_Fee_Including_18_GST__c;
                                if(objSelectedProduct.EndDate__c!=null){
                                    objOLI.CEE_TermEndDate__c = (objSelectedProduct.EndDate__c);
                                    
                                }
                            }
                            
                            if( objOLI.CEE_TermEndDate__c == null ){
                                objOLI.CEE_TermEndDate__c = objSelectedProduct.EndDate__c;
                                
                            }
                            system.debug('before addingg'+objOLI);
                            list_OpportunityLineItems.add(objOLI);
                        }
                    }
                    
                    else if(objSelectedProduct.Family == 'SDP' ){
                        Decimal decimalProductPrice = CEE_DataSelector.GetPriceofProgram(objSelectedProduct.Id,objPriceEntry.Pricebook2.Name);
                        
                        OpportunityLineItem objOLI = new OpportunityLineItem();
                        objOLI.Product2Id = objSelectedProduct.Id;
                        objOLI.Quantity = 1 ;
                        objOLI.UnitPrice = decimalProductPrice;
                        objOLI.OpportunityId = curoppObj.Id;
                        objOLI.Description = objSelectedProduct.Description;
                        objOLI.CEE_Term__c = 1;
                        objOLI.CEE_ContactEmail__c = contactObj.Email;
                        
                        objOLI.CEE_PaymentStatus__c = 'Not Paid';
                        
                        
                        list_OpportunityLineItems.add(objOLI);
                    }
                    
                    
                }
            }
            if(list_OpportunityLineItems.size()>0){
                insert list_OpportunityLineItems;
            }
            
            
            
            
            
            system.debug('Inside quote');
            //Map<Id,Opportunity> map_OldOpportuntiesById,
            List<OpportunityLineItem> list_OppLineItems = CEE_DataSelector.GetOppLineItems(map_NewOpportuntiesById.keyset());
            Map<Id,List<OpportunityLineItem>> map_OpportunityIdByLineItem = new Map<Id,List<OpportunityLineItem>>();
            for(OpportunityLineItem objOppLineItem:list_OppLineItems){
                
                if(map_OpportunityIdByLineItem.containsKey(objOppLineItem.OpportunityId)){
                    List<OpportunityLineItem> list_OppLineList = map_OpportunityIdByLineItem.get(objOppLineItem.OpportunityId);
                    list_OppLineList.add(objOppLineItem);
                }
                else{
                    map_OpportunityIdByLineItem.put(objOppLineItem.OpportunityId,new list<OpportunityLineItem>{objOppLineItem});
                }
                
                
                
            }
            List<Quote>  list_Quotes = new List<Quote>();
            List<QuoteLineItem> list_QuoteLineItems = new List<QuoteLineItem>();
            Map<Decimal,String> map_OrderByMail = new Map<Decimal,String>();
            Map<String,String> map_EmailByUserId = new Map<String,String>();
            List<GroupMember> list_GroupMembers = new list<GroupMember>();
            Map<String,List<Id>> Map_GroupIdByUserIds = new Map<String,List<Id>>();
            Map<String,String> Map_GroupIdByName = new Map<String,String>();
            /* List<CEE_QuoteApprover__mdt> listApproverRecs = [SELECT Id,MasterLabel,CEE_EMail__c,CEE_Order__c from CEE_QuoteApprover__mdt order by CEE_Order__c asc];
for(CEE_QuoteApprover__mdt objApprover:listApproverRecs){
map_OrderByMail.put(objApprover.CEE_Order__c,objApprover.CEE_EMail__c);
}
List<User> list_Approvers = [select Id,email from user where email in :map_OrderByMail.values()];
for(User objCurUser:list_Approvers){
map_EmailByUserId.put(objCurUser.email,objCurUser.Id);
}*/
            /*List<Group> list_ApproverGroups = CEE_DataSelector.GetApproverGroups();
            for(Group objCurGroup : list_ApproverGroups){
                Map_GroupIdByName.put(objCurGroup.Id,objCurGroup.Name);
            }
            if(list_ApproverGroups.size()>0){
                list_GroupMembers = [SELECT GroupId,Group.DeveloperName, UserOrGroupId FROM GroupMember WHERE GroupId in :Map_GroupIdByName.keyset()]; 
                for(GroupMember objGroupMember : list_GroupMembers){
                    String strGroupName = String.valueOf(objGroupMember.Group.DeveloperName);
                    if(Map_GroupIdByUserIds.containsKey(strGroupName)){
                        List<Id> listCurrentGroup  = Map_GroupIdByUserIds.get(strGroupName);
                        listCurrentGroup.add(objGroupMember.UserOrGroupId);
                        Map_GroupIdByUserIds.put(strGroupName,listCurrentGroup);
                    }
                    else{
                        Map_GroupIdByUserIds.put(strGroupName,new list<Id>{objGroupMember.UserOrGroupId});
                    }
                    
                }
                
            }
            system.debug('testtt'+Map_GroupIdByUserIds);
            for(String strCurOppId : map_NewOpportuntiesById.keyset()){
                // String strOldStageName = map_OldOpportuntiesById.get(strCurOppId).StageName;
                // String strNewStageName = map_NewOpportuntiesById.get(strCurOppId).StageName;
                String strOpportunityName = map_NewOpportuntiesById.get(strCurOppId).Name;
                // String AccountId = map_NewOpportuntiesById.get(strCurOppId).AccountId;
                //  if(strOldStageName != strNewStageName && (strNewStageName == System.Label.CLCEE00007 && strOldStageName == System.Label.CLCEE00006)){
                Quote objQuote = new Quote();
                objQuote.OpportunityId = strCurOppId;
                objQuote.Name = 'Quote_'+strOpportunityName;
                objQuote.Status = 'Created';
                List<String> GroupNames = new list<string>{'CEE_Quote_Approval_First_Stage_Group','CEE_Quote_Approval_Second_Stage_Group','CEE_Quote_Approval_Third_Stage_Group','CEE_Quote_Approval_Fourth_Stage_Group','CEE_Quote_Approval_Fifth_Stage_Group'};
                    Integer Intcounter = 0;
                for(integer i=0;i<GroupNames.size();i++){
                    
                    Intcounter = Intcounter+1;
                    String FirstField = 'CEE_Approver_'+Intcounter+'__c';
                    Intcounter = Intcounter+1;
                    String SecondField = 'CEE_Approver_'+Intcounter+'__c';
                    Intcounter = Intcounter+1;
                    String ThirdField = 'CEE_Approver_'+Intcounter+'__c';
                    system.debug('Group Name'+GroupNames[i]);
                    if(Map_GroupIdByUserIds.containsKey(GroupNames[i])){
                        List<Id> list_UserIds = Map_GroupIdByUserIds.get(GroupNames[i]);
                        Integer UserSIze = list_UserIds.size();
                        if(UserSIze>0) objQuote.put(FirstField,list_UserIds[0]);
                        if(UserSIze>1) objQuote.put(SecondField,list_UserIds[1]);
                        if(UserSIze>2) objQuote.put(ThirdField,list_UserIds[2]);
                        system.debug('before'+objQuote);
                    }
                }
                
                
                system.debug(objQuote);
                
                list_Quotes.add(objQuote);
                //}
            }
            
            insert list_Quotes;
            
            for(Quote objQuote:list_Quotes){
                List<OpportunityLineItem> list_CurOppLineItems = map_OpportunityIdByLineItem.get(objQuote.OpportunityId);
                if(list_CurOppLineItems.size()>0){
                    for(OpportunityLineItem objCurLineItem:list_CurOppLineItems){
                        
                        QuoteLineItem objCurLine = new QuoteLineItem();
                        objCurLine.QuoteId = objQuote.Id;
                        objCurLine.Product2Id = objCurLineItem.Product2Id;
                        objCurLine.UnitPrice = objCurLineItem.UnitPrice;
                        objCurLine.PricebookEntryId = objCurLineItem.PricebookEntryId;
                        objCurLine.Discount = objCurLineItem.Discount;
                        objCurLine.CEEOpportunityLineId__c = objCurLineItem.Id;
                        //objCurLine.TotalPrice = objCurLineItem.TotalPrice;
                        objCurLine.Quantity = objCurLineItem.Quantity;
                        //objCurLine.Subtotal = objCurLineItem.Subtotal;
                        list_QuoteLineItems.add(objCurLine);
                        
                    }
                }
            }
            if(list_QuoteLineItems.size()>0){
                insert list_QuoteLineItems;
            }
        }
        catch(Exception e) {  
            //new LogException().Module('CEE Opportunity Trigger Handler Module').log(e);
        }
    }*/
    
    
    public static void sendLDPOfferEmailToContact(set<Id> oppIdSet){
        database.executeBatch(new Batchable_sendLDPOfferEmail(oppIdSet),200);
    } 
    
    public static void updateProgrammeManager(List<Opportunity> oppList){
        Set<Id> productIds = new Set<Id>();
        for(Opportunity opp : oppList){
            if(opp.APP_Product__c != null){
                productIds.add(opp.APP_Product__c);
            }
        }
        if(productIds.isEmpty()) return;
        Map<Id, Product2> productMap = new Map<Id, Product2>(
            [SELECT Id, Programme_Manager__c FROM Product2 WHERE Id IN :productIds]
        );
        for(Opportunity opp : oppList){
            if(opp.APP_Product__c != null && productMap.containsKey(opp.APP_Product__c)){
                opp.Program_Manager__c = productMap.get(opp.APP_Product__c).Programme_Manager__c;
            }
        }
    }
    
    public static void ClonetoContacts(Map<Id,Opportunity> map_OpportuntiesById) {
        system.debug('Inside trigger');
        try{
            for(String StrOppId : map_OpportuntiesById.keyset()){
                Opportunity objCurOpp = map_OpportuntiesById.get(StrOppId);
                Contact objCurContact = new Contact();
                objCurContact.Id = objCurOpp.APP_Contact__c;
                objCurContact.Prefix__c = objCurOpp.APP_Prefix__c;
                //assign rest of the fields from opp to contact after here
                
                
                //personal details
                objCurContact.firstname = objCurOpp.APP_First_Name__c;
                objCurContact.lastname = objCurOpp.APP_Last_Name__c;
                objCurContact.middlename = objCurOpp.APP_MiddleName__c;
                objCurContact.Email = objCurOpp.APP_Email__c;
                objCurContact.hed__Gender__c = objCurOpp.APP_Gender__c;
                objCurContact.Country__c = objCurOpp.APP_Country__c;
                objCurContact.Birthdate = objCurOpp.APP_Birthdate__c;
                objCurContact.Citizenship__c = objCurOpp.APP_Citizeship__c;
                
                //contact details
                objCurContact.Designation__c = objCurOpp.APP_Designation__c;
                objCurContact.Company__c = objCurOpp.APP_Company__c;
                objCurContact.Website__c = objCurOpp.APP_Website__c;
                objCurContact.City__c = objCurOpp.APP_City__c;
                //  objCurContact.Current_Postal_Code__c = String.valueOf(objCurOpp.APP_Pincode__c);
                objCurContact.Current_Postal_Code__c = String.valueOf(objCurOpp.APP_Pincode_New__c);
                //  objCurContact.hed_Country__c = objCurOpp.CEE_Country__c;
                objCurContact.Phone = objCurOpp.APP_MobilePhone__c;            
                objCurContact.PhoneCode__c = objCurOpp.APP_PhoneCode__c;
                
                //organizational details
                objCurContact.Select_Current_Industry__c = objCurOpp.APP_CurrentIndustry__c;
                
                objCurContact.Annual_Sales_in_INR__c = objCurOpp.APP_AnnualSales1__c;
                objCurContact.Number_of_Employees__c = objCurOpp.APP_NumberofEmployees__c;
                objCurContact.Annual_Compensation__c = objCurOpp.APP_AnnualCompensationincludingBonus1__c;
                objCurContact.Describe_organisational_functional_Hi__c = objCurOpp.APP_DescribeOrganizationalHierarchy__c;
                objCurContact.Title_of_Reporting_Manager__c = objCurOpp.APP_TitleofReportingManager__c;
                objCurContact.Select_Function__c = objCurOpp.APP_SelectFunction__c;
                objCurContact.year_of_experience__c = objCurOpp.APP_TotalYearsofExperience__c;
                objCurContact.Current_Responsibilities__c = objCurOpp.APP_CurrentResponsibilities__c;
                //Education details
                objCurContact.FirstUniversity__c  = objCurOpp.APP_First_University__c;
                objCurContact.SecondUniversity__c = objCurOpp.APP_Second_University__c;
                objCurContact.ThirdUniversity__c = objCurOpp.APP_ThirdUniversity__c;
                
                objCurContact.Year1__c = objCurOpp.APP_Year__c; 
                objCurContact.Year2__c = objCurOpp.APP_Year1__c;
                objCurContact.Year3__c  = objCurOpp.APP_Year2__c;
                
                objCurContact.HighestDegreeattained1__c = objCurOpp.APP_FirstHighestDegreeattained__c;
                objCurContact.SecondHighestDegreeattained__c = objCurOpp.APP_SecondHighestDegreeattained__c;
                objCurContact.ThirdHighestDegreeAttained__c = objCurOpp.APP_ThirdHighestDegreeAttained__c;
                //Work ex
                List<Work_Ex__c> list_WorkEx = [SELECT CEE_Opportunity__c,
                                                Contact__c
                                                FROM Work_Ex__c
                                                WHERE CEE_Opportunity__c=:objCurOpp.Id];
                system.debug(list_WorkEx+'list_WorkEx');
                for(Integer i=0;i<list_WorkEx.size();i++){
                    list_WorkEx[i].Contact__c = objCurOpp.APP_Contact__c;
                }
                if(list_WorkEx.size()>0){
                    update list_WorkEx;
                }
                
                //Objectives
                List<CEE_Contact_ProgramObjective__c> list_objContProgram = [SELECT id 
                                                                             FROM CEE_Contact_ProgramObjective__c
                                                                             WHERE Opportunity__c =:StrOppId];
                if(list_objContProgram.size()>0){
                    list_objContProgram[0].Contact__c = objCurOpp.APP_Contact__c;
                    
                    
                    update list_objContProgram[0];
                }
                List<CEE_Contact_ProgramNomination__c> list_objConNomination = [SELECT Id,
                                                                                Contact__c 
                                                                                FROM CEE_Contact_ProgramNomination__c 
                                                                                WHERE Opportunity__c =:StrOppId];
                if(list_objConNomination.size()>0){                           
                    list_objConNomination[0].Contact__c = objCurOpp.APP_Contact__c;
                    update list_objConNomination[0];
                }
                objCurContact.Prefix__c = objCurOpp.APP_Prefix_Nominating__c;
                //   objCurContact.LastName = objCurOpp.Name;   //Adding by Anil it is a requied field
                objCurContact.InvoicePosition__c = objCurOpp.APP_Titile_or_Position_Nominating__c;
                objCurContact.InvoiceOrganizationName__c = objCurOpp.APP_Nomination_Organization_Name__c;
                objCurContact.InvoiceMobile__c = objCurOpp.APP_HR_Nomination_Phone_Number__c;
                objCurContact.InvoiceLastName__c = objCurOpp.APP_HR_Nomination_Last_Name__c;
                objCurContact.InvoiceFirstName__c = objCurOpp.APP_HR_Nomination_First_Name__c;
                objCurContact.InvoiceEmail__c = objCurOpp.APP_HR_Nomination_Email__c;
                objCurContact.Current_Address_Line_1__c = objCurOpp.APP_InvoiceAddress1__c;
                objCurContact.Current_Address_Line_2__c = objCurOpp.APP_InvoiceAddress2__c;
                objCurContact.City__c = objCurOpp.APP_InvoiceCity__c;
                objCurContact.Country__c = objCurOpp.APP_InvoiceCountry__c;
                objCurContact.State__c = objCurOpp.APP_InvoiceState__c;
                //objCurContact.Current_Postal_Code__c = objCurOpp.APP_InvoicePincode__c
                objCurContact.PAN_Number__c = objCurOpp.APP_Pan__c;
                objCurContact.GST_Number__c = objCurOpp.APP_GSTNumber__c;
                objCurContact.SEZCertificate__c = objCurOpp.APP_HasSEZCertificate__c;
                update objCurContact;
                
            }
        }
        catch(Exception e) {  
            new LogException().Module('CEE Opportunity Trigger Handler Clone Contacts Module').log(e);
        }
        
    }
    
    
    
    
    /* * @author      :   Sumanyu Purohit
* @description :    To send numbers to Ozonetel
* @param       :    newopplist : Trigger.new
* @return      :    void
**/
    public static void sendnumbertozonetel(List<Opportunity> newopplist){
        
        if(newopplist.size()==1){
            try{
                System.debug('enter');
                OzoneTel_Api_Detail__mdt  apidetail = [Select DeveloperName , Apikey__c from  OzoneTel_Api_Detail__mdt limit 1];
                Http ht = new Http();
                HttpRequest req = new HttpRequest(); 
                req.setHeader('Connection', 'keep-alive');
                req.setHeader('Accept-Encoding', 'gzip, deflate, br');
                String baseurl = 'https://api1.cloudagent.in/cloudAgentRestAPI/index.php/CloudAgent/CloudAgentAPI/addCamapaignData';
                baseurl =  baseurl +'?api_key=' + apidetail.Apikey__c + '&campaign_name=' + apidetail.DeveloperName + '&format=json&PhoneNumber=' + newopplist[0].APP_MobilePhone__c + '&action=start&checkDuplicate=true';
                req.setMethod('GET');
                req.setEndpoint(baseurl);
                HttpResponse response = ht.send(req);
                System.debug('Status Code==>' +  response.getStatusCode());
                System.debug('Status Body==>' + response.getBody());
            }
            catch(Exception e)
            {
                new LogException().log(e);
            }
        }
        
        
    }
    
    /* * @author      :    Pavan Kumar
* @description :    To send email to candidates after saving opp
* @param       :    list_Opportunties - records to send email to
* @return      :    void
**/
    /*public static void Sendmailstocandidates(Map<Id,Opportunity> map_NewOpportuntiesById){
        system.debug('inside handler');
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        EmailTemplate emailTemplate = new EmailTemplate();
        List<Opportunity> list_MailOpps = new List<Opportunity>();
        List<Opportunity> list_CurrentOpps = [SELECT APP_First_Name__c,
                                              APP_Last_Name__c,
                                              APP_SelectedProgramName__c,
                                              APP_Applicationformstatus__c,
                                              opportunity__c,
                                              APP_Email__c,
                                              opportunity__r.APP_Email__c,
                                              APP_is_HR_Nominated__c
                                              FROM Opportunity 
                                              WHERE id in :map_NewOpportuntiesById.keyset()
                                              AND APP_is_HR_Nominated__c=true ];
        try{
            for(Opportunity objOpp :list_CurrentOpps){
                String strstatus = objOpp.APP_Applicationformstatus__c;
                if(strstatus!=null && !(strstatus.contains('100')) && objOpp.APP_is_HR_Nominated__c){
                    list_MailOpps.add(objOpp);
                }
            }
            emailTemplate =    [Select Id,Subject,Description,HtmlValue,DeveloperName,Body from EmailTemplate WHERE IsActive=true and DeveloperName='Reminder_for_HR_nominated_candidate']; 
            List<OrgWideEmailAddress> CurAddresses =    [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress where Address = 'cee@isb.edu'];
            
            
            if(list_MailOpps.size()>0){ 
                system.debug('inside listmails'+list_MailOpps);    
                for(Opportunity objOpp : list_MailOpps){
                    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
                    message.setSaveAsActivity(false);
                    message.setTemplateID(emailTemplate.Id);
                    Contact ct = [select id from contact  where email!=null limit 1];
                    message.setTargetObjectId(ct.Id);
                    message.setTreatTargetObjectAsRecipient(false);
                    message.setWhatId(objOpp.Id);
                    List<String> listAddr = new List<String>();
                    listAddr.add(objOpp.APP_Email__c);
                    //listAddr.add('pavankumar.gudavalli@absyz.com');
                    if(objOpp.opportunity__c!=null){
                        string[] list_ccadd = new list<string>();
                        list_ccadd.add( objOpp.opportunity__r.APP_Email__c);
                        message.setCcAddresses(list_ccadd);
                    }
                    message.toAddresses = listAddr;
                    if(CurAddresses.size()>0){
                        message.setOrgWideEmailAddressId(CurAddresses[0].Id); 
                    }
                    emails.add(message);  
                }
                if(emails.size() > 0){
                    Messaging.SendEmailResult[] results = Messaging.sendEmail(emails);  
                    if (results[0].success){
                        System.debug('The email was sent successfully.');
                    } else {
                        System.debug('The email failed to send: ' +results[0].errors[0].message);
                    }
                }
            }
        }
        
        catch(Exception e) {  
            new LogException().Module('CEE Opportunity Trigger Handler Send Email Module').log(e);
        }
    }*/
    
    @InvocableMethod
    public static void DeleteolFileofOpp(List<String> OppRecIds){
        String OppRecId = OppRecIds[0];
        Set<ContentDocumentLink> DeleteFiles = new  Set<ContentDocumentLink>();
        List<ContentDocumentLink> ResumeFiles =[ SELECT id,LinkedEntityId,ContentDocumentId,ContentDocument.Title
                                                FROM ContentDocumentLink 
                                                WHERE LinkedEntityId=:OppRecId 
                                                AND ContentDocument.Title like 'Resume_%' 
                                                ORDER BY systemmodstamp DESC];
        List<ContentDocumentLink> SezFiles =[ SELECT id,LinkedEntityId,ContentDocumentId,ContentDocument.Title
                                             FROM ContentDocumentLink 
                                             WHERE LinkedEntityId=:OppRecId 
                                             AND ContentDocument.Title like 'Sez_%' 
                                             ORDER BY systemmodstamp DESC];
        system.debug(ResumeFiles+'ResumeFiles');
        system.debug(ResumeFiles.size()+'ResumeFiles size');
        try{
            if(ResumeFiles.size()>0){
                ResumeFiles.remove(0);
            }
            if(SezFiles.size()>0){
                SezFiles.remove(0);
            }
            system.debug('DeleteFiles'+DeleteFiles);
            if(ResumeFiles.size()>0){
                Delete ResumeFiles;
            }
            if(SezFiles.size()>0){
                Delete SezFiles;
            }
        }
        
        catch(Exception e) {  
            new LogException().Module('CEE Opportunity Trigger Handler Module').log(e);
        }
    }
    
    public static void updateLeadSource(List<Opportunity> oppList){
        List<Opportunity> updateOpp = new List<Opportunity>();
        Map<String,Opportunity> oppMap = new Map<String,Opportunity>();
        Set<String> oppProductCode = new Set<String>();
        Set<String> oppEmail = new Set<String>();
        
        Map<String,Lead> leadMap = new Map<String,Lead>();
        try{
            for(Opportunity opp:oppList){
                System.debug(opp.ProductCode__c);
                String oppEmailandCode = opp.ProductCode__c+'*'+opp.APP_Email__c;
                oppProductCode.add(opp.ProductCode__c);
                oppEmail.add(opp.APP_Email__c);
                oppMap.put(oppEmailandCode,opp);
            }
            
            List<Lead> leadList = [Select Id,CEE_ProductCode__c,Email,CreatedDate,UTM_Source__c from Lead where Email IN :oppEmail and CEE_ProductCode__c IN :oppProductCode Limit 1];
            
            for(Lead lead:leadList){
                String leadEmailandCode = lead.CEE_ProductCode__c+'*'+lead.Email;
                leadMap.put(leadEmailandCode,lead);
            }
            
            if(leadList.size() > 0){
                for(String leadDetails:leadMap.keySet()){
                    Opportunity opp = oppMap.get(leadDetails);
                    opp.UTM_Source__c = leadMap.get(leadDetails).UTM_Source__c;
                    opp.Lead_Created_Date__c = leadMap.get(leadDetails).CreatedDate;
                    updateOpp.add(opp);
                }
            }
        }
        
        catch(Exception e) {  
            new LogException().Module('CEE Opportunity Trigger Handler Module').log(e);
        }
    }
    
    public static void createParticipantInfo(List<Opportunity> oppList){
        System.debug('inside this class');
        List<CEE_Participant_Info__c> getParticipantInfo = new List<CEE_Participant_Info__c>();
        List<CEE_Participant_Info__c> participantList = new List<CEE_Participant_Info__c>();
        Map<String,Opportunity> oppMap = new Map<String,Opportunity>();
        Set<Id> oppContact = new Set<Id>();
        Set<String> oppContactEmail = new Set<String>();
        Set<Id> oppProduct = new Set<Id>();
        Contact contactObj=new Contact();
        Id ceeOpenLDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Id ceeOpenSDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-SDP').getRecordTypeId();
        Id ceeHR = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
        Id onlineProgram = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Online Program').getRecordTypeId();
        Id execEdRT = Schema.SObjectType.CEE_Participant_Info__c.getRecordTypeInfosByDeveloperName().get('ExecEd').getRecordTypeId();
        Id onlineRT = Schema.SObjectType.CEE_Participant_Info__c.getRecordTypeInfosByDeveloperName().get('Online_Program').getRecordTypeId();

        for(Opportunity opp:oppList){
            if(opp.RecordTypeId == ceeOpenLDP || opp.RecordTypeId == ceeOpenSDP || opp.RecordTypeId == ceeHr || opp.RecordTypeId == onlineProgram){
                if(String.valueOf(opp.APP_Contact__c) != null && String.valueOf(opp.APP_Contact__c) != '' )
                    oppContact.add(opp.APP_Contact__c);
                else
                    oppContactEmail.add(opp.APP_Email__c);
                if(String.valueOf(opp.APP_Product__c) != null && String.valueOf(opp.APP_Product__c) != '' )
                    oppProduct.add(opp.APP_Product__c);
            }
        }
        if((oppContact.size() > 0 || oppContactEmail.size() > 0) && oppProduct.size() > 0){
            if(oppContact.size() > 0)
                getParticipantInfo = [Select Id from CEE_Participant_Info__c where Contact_Name__c IN :oppContact and Program_Name__c IN :oppProduct];
            if(getParticipantInfo.size() == 0){
                for(Opportunity opp:oppList){
                    CEE_Participant_Info__c createParticipant = new CEE_Participant_Info__c();
                    if(opp.APP_Contact__c != null)
                        createParticipant.Contact_Name__c = opp.APP_Contact__c;
                    else{
                        createParticipant.Contact_Email_Id__c = opp.APP_Email__c;
                    }
                    createParticipant.Program_Name__c = opp.APP_Product__c;
                    //createParticipant.RecordTypeId = recordTypeId;

                    if(opp.RecordTypeId == onlineProgram) {
                        createParticipant.RecordTypeId = onlineRT;
                    } else {
                        createParticipant.RecordTypeId = execEdRT;
                    }

                    participantList.add(createParticipant);
                }
            }
        } 
        if(participantList.size() > 0)
            insert participantList;
    }
    
    
    public static void createLead(List<Opportunity> oppList){
        List<Lead> newleadList = new List<Lead>();
        List<lead> updateLeadList = new List<Lead>();
        Id devRecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('ExecEd').getRecordTypeId();
        Id leadRecordType = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('ExecEd HFP').getRecordTypeId();
        Id leadExedB2BRecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('ExecEd B2B').getRecordTypeId();
        Map<String,Opportunity> oppMap = new Map<String,Opportunity>();
        Map<Id,Opportunity> map_IdByOpportunity = new Map<Id,Opportunity>();
        Set<String> oppProductCode = new Set<String>();
        Set<String> oppEmail = new Set<String>();
        Set<String> oppMobile = new Set<String>();
        Set<String> oppId = new Set<String>();
        Map<String,Lead> leadMap = new Map<String,Lead>();
        Map<String,Lead> leadCodeAndEmail = new Map<String,Lead>();
        Map<String,Lead> leadCodeAndMobile = new Map<String,Lead>();
        Id ceeOpenLDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Id ceeOpenSDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-SDP').getRecordTypeId();
        Id ceeHR = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
        for(Opportunity opp:oppList){
            if(opp.RecordTypeId == ceeOpenLDP || opp.RecordTypeId == ceeOpenSDP || opp.RecordTypeId == ceeHr){
                String oppEmailandCodeandMobile = opp.ProductCode__c+'*'+opp.APP_Email__c+'*'+opp.APP_MobilePhone__c;
                if(opp.ProductCode__c != null && opp.ProductCode__c != '' )
                    oppProductCode.add(opp.ProductCode__c);
                if(opp.APP_Email__c != null && opp.APP_Email__c != '' )
                    oppEmail.add(opp.APP_Email__c);
                if(opp.APP_MobilePhone__c != null && opp.APP_MobilePhone__c != '' )
                    oppMobile.add(opp.APP_MobilePhone__c);
                oppId.add(opp.id);
                oppMap.put(oppEmailandCodeandMobile,opp);
                
            }
        }
        Map<Id,Opportunity> map_Opp = new Map<Id,Opportunity>([SELECT Id ,App_product__r.High_Focused_Program__c, name,App_product__c,ProductCode__c,APP_Email__c ,APP_MobilePhone__c FROM Opportunity where id IN:oppId ]);
        List<Opportunity> listOpp = [SELECT Id ,Account_Name__c,APP_Designation__c,APP_NominatedBy__c,App_product__r.High_Focused_Program__c, name,App_product__c,ProductCode__c,APP_Gender__c,APP_Email__c ,APP_MobilePhone__c,(Select Id from Leads__r) FROM Opportunity where id IN:oppId];
        system.debug('in the personal list oppp+'+ listOpp);
        Map<String, Opportunity> map_OpportunityByCode = new Map<String, Opportunity>();
        for (Opportunity objOpportunity : listOpp) {
            String oppEmailandCodeandMobile = objOpportunity.ProductCode__c+'*'+objOpportunity.APP_Email__c+'*'+objOpportunity.APP_MobilePhone__c;
            map_OpportunityByCode.put(oppEmailandCodeandMobile, objOpportunity);
            map_IdByOpportunity.put(objOpportunity.Id,objOpportunity);
        }
        if(test.isRunningTest()){
            oppProductCode.add('ece');
        }
        if(oppProductCode.size() > 0 && oppEmail.size() > 0 && oppMobile.size() > 0){
            List<Lead> leadList = [Select Id,Name,Email,FormID__c,UTM_Source__c,MobilePhone,CEE_ProductCode__c from lead where Status!= 'Lost' and (RecordTypeId =:devRecordTypeId or RecordTypeId =:leadExedB2BRecordTypeId) and CEE_ProductCode__c IN :oppProductCode and (MobilePhone IN :oppMobile OR Email IN :oppEmail) Order by CreatedDate Limit 1];
            if(leadList.size() > 0){
                for(Lead lead:leadList){
                    String leadEmailandCodeandMobile = lead.CEE_ProductCode__c+'*'+lead.Email+'*'+lead.MobilePhone;
                    String leadCodeAndEmailString =lead.CEE_ProductCode__c+'*'+lead.Email;
                    String leadCodeAndMobileString = lead.CEE_ProductCode__c+'*'+lead.MobilePhone;
                    leadMap.put(leadEmailandCodeandMobile,lead);
                    leadCodeAndEmail.put(leadCodeAndEmailString,lead);
                    leadCodeAndMobile.put(leadCodeAndMobileString,lead);
                }
                for(Opportunity opp:listOpp){
                    String codeEmailMobile = opp.ProductCode__c+'*'+opp.APP_Email__c+'*'+opp.APP_MobilePhone__c;
                    String codeEmail = opp.ProductCode__c+'*'+opp.APP_Email__c;
                    String codeMobile = opp.ProductCode__c+'*'+opp.APP_MobilePhone__c;
                    if(opp.Leads__r.size() == 0){
                        if(!leadMap.containsKey(codeEmailMobile) && !leadCodeAndEmail.containsKey(codeEmail) && !leadCodeAndMobile.containsKey(codeMobile)){
                            Lead lead = new Lead();
                            lead.LastName = opp.Name;
                            lead.Company = opp.Account_Name__c;
                            lead.UTM_Source__c = 'Direct';
                            lead.Email = opp.APP_Email__c;
                            lead.Status = 'Closed';
                            lead.CEE_ProductCode__c = opp.ProductCode__c;
                            lead.Opportunity__c = opp.Id;
                            lead.Gender__c = opp.APP_Gender__c;
                            lead.Designation__c = opp.APP_Designation__c;
                            lead.MobilePhone = opp.APP_MobilePhone__c;
                            if(opp.APP_NominatedBy__c == 'Self'){
                                lead.Lead_Type__c = 'B2C';
                            }
                            else if(opp.APP_NominatedBy__c == 'Sponsored by Company'){
                                lead.Lead_Type__c = 'B2B';
                            }
                            opp.UTM_Source__c = 'Direct';
                            opp.Form_Id__c = String.valueOf(lead.FormID__c);
                            // lead.RecordTypeId = devRecordTypeId;
                            system.debug('testlistOpp[0].App_product__r.High_Focused_Program__c11'+ listOpp[0].App_product__r.High_Focused_Program__c);
                            if (opp.App_product__r.High_Focused_Program__c == true ) {
                                lead.RecordTypeId = leadRecordType;
                            }else{
                                lead.RecordTypeId = devRecordTypeId;
                            }
                            newLeadList.add(lead); 
                        }
                        else{
                            Lead currentLead1 = leadMap.get(codeEmailMobile);
                            Lead currentLead2 = leadCodeAndEmail.get(codeEmail);
                            Lead currentLead3 = leadCodeAndMobile.get(codeMobile);
                            if(currentLead1 != null){
                                currentlead1.Opportunity__c = opp.Id;
                                if(opp.APP_NominatedBy__c == 'Self'){
                                    currentlead1.Lead_Type__c = 'B2C';
                                }
                                else if(opp.APP_NominatedBy__c == 'Sponsored by Company'){
                                    currentlead1.Lead_Type__c = 'B2B';
                                }
                                updateLeadList.add(currentLead1);
                                opp.UTM_Source__c = currentLead1.UTM_Source__c;
                                opp.Form_Id__c = String.valueOf(currentLead1.FormID__c); 
                            }
                            else if(currentLead2 != null){
                                currentlead2.Opportunity__c = opp.Id;
                                if(opp.APP_NominatedBy__c == 'Self'){
                                    currentlead2.Lead_Type__c = 'B2C';
                                }
                                else if(opp.APP_NominatedBy__c == 'Sponsored by Company'){
                                    currentlead2.Lead_Type__c = 'B2B';
                                }
                                updateLeadList.add(currentLead2);
                                opp.UTM_Source__c = currentLead2.UTM_Source__c;
                                opp.Form_Id__c = String.valueOf(currentLead2.FormID__c); 
                                
                            }
                            else if(currentLead3 != null){
                                currentlead3.Opportunity__c = opp.Id;
                                if(opp.APP_NominatedBy__c == 'Self'){
                                    currentlead3.Lead_Type__c = 'B2C';
                                }
                                else if(opp.APP_NominatedBy__c == 'Sponsored by Company'){
                                    currentlead3.Lead_Type__c = 'B2B';
                                }
                                updateLeadList.add(currentLead3);
                                opp.UTM_Source__c = currentLead3.UTM_Source__c;
                                opp.Form_Id__c = String.valueOf(currentLead3.FormID__c); 
                                
                            }
                            
                        }
                    }
                    
                    if(updateleadList.size() > 0)
                        update updateLeadList;
                    if(newLeadList.size() > 0)
                        insert newLeadList;
                    system.debug('inserting the first lead'+newLeadList);
                }
            }
            else{
                for(Opportunity opp:oppList){
                    Opportunity oppCheck = map_IdByOpportunity.get(opp.Id);
                    if(oppCheck.Leads__r.size() == 0){
                        Lead lead = new Lead();
                        lead.LastName = opp.Name;
                        lead.Company = opp.Account_Name__c;
                        lead.UTM_Source__c = 'Direct';
                        lead.Email = opp.APP_Email__c;
                        lead.Status = 'Closed';
                        lead.CEE_ProductCode__c = opp.ProductCode__c;
                        lead.Opportunity__c = opp.Id;
                        lead.Gender__c = opp.APP_Gender__c;
                        lead.Designation__c = opp.APP_Designation__c;
                        lead.MobilePhone = opp.APP_MobilePhone__c;
                        // lead.RecordTypeId = devRecordTypeId;
                        opp.UTM_Source__c = 'Direct';
                        opp.Form_Id__c = String.valueOf(lead.FormID__c);
                        if(opp.APP_NominatedBy__c == 'Self'){
                            lead.Lead_Type__c = 'B2C';
                        }
                        else if(opp.APP_NominatedBy__c == 'Sponsored by Company'){
                            lead.Lead_Type__c = 'B2B';
                        }
                        
                        String oppEmailandCodeandMobile = opp.ProductCode__c+'*'+opp.APP_Email__c+'*'+opp.APP_MobilePhone__c;
                        if(map_OpportunityByCode.get(oppEmailandCodeandMobile) != null)
                            if (map_OpportunityByCode.get(oppEmailandCodeandMobile).App_product__r.High_Focused_Program__c ) {
                                lead.RecordTypeId = leadRecordType;
                            }
                        else
                            lead.RecordTypeId = devRecordTypeId;
                        else{
                            system.debug('devRecordTypeId'+devRecordTypeId);
                            lead.RecordTypeId = devRecordTypeId;
                        }
                        newLeadList.add(lead);
                    }
                    if(newLeadList.size() > 0)
                        insert newLeadList;
                    system.debug('inserting the second list'+newLeadList);
                }
            }
        }
    }
    
    public static void updateOppApplicationStage(List<Opportunity> oppList){
        Id ceeOpenLDPrecType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Id ceeOpenSDPrecType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-SDP').getRecordTypeId();
        Id ceeHRrecType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
        Id ceeOnlinerecType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Online Program').getRecordTypeId();
        String applicationInProgress = System.Label.CLCEE00029;
        String applied = System.Label.CLCEE00025;
        String offerOpen = System.Label.CLCEE00007;
        String interviewsScheduled = System.Label.CLCEE00017;
        String waitlisted = system.Label.CLCEE00006;
        String interviewed = System.Label.CLCEE00027;
        String withdraw = System.Label.CLCEE00030;
        String lost = System.Label.CLCEE00031;
        String deferredDecision = System.Label.CLCEE00032;
        String withdrew = System.Label.CLCEE00033;
        String rejected = System.Label.CLCEE00034;
        String payment = System.Label.CLCEE00035;
        String offerAccepted = System.Label.CLCEE00016;
        String blockingFee = System.Label.CLCEE00036;
        String proformaInvoice = System.Label.CLCEE00037;
        for(opportunity opp : oppList){
            if(opp.RecordTypeId == ceeOpenLDPrecType || opp.RecordTypeId == ceeOpenSDPrecType || opp.RecordTypeId == ceeHRrecType){   
                if(opp.StageName == payment || opp.StageName == offerAccepted || opp.StageName == blockingFee || opp.StageName == proformaInvoice){
                    opp.Participant__c = true;
                    if(opp.Enrollment_Date__c == null){
                        opp.Enrollment_Date__c = System.NOW();
                    }
                }
                else{
                    opp.Participant__c = false;
                    opp.Enrollment_Date__c = null;
                }
            }
            if(opp.RecordTypeId == ceeOnlinerecType && (opp.StageName == 'Student' || opp.Payment_Status__c == 'PAID' || opp.Payment_Status__c == 'PAID OFFLINE')){
                if(opp.Enrollment_Date__c == null){
                    opp.Enrollment_Date__c = System.NOW();
                }
                
            }
        }
        
    }    
    
    
    public static void updateLeadOppStage(Map<id,opportunity> mapOpp,Map<id,opportunity> mapOldOpp){
        String applicationInProgress = System.Label.CLCEE00029;
        String applied = System.Label.CLCEE00025;
        String offerOpen = System.Label.CLCEE00007;
        String interviewsScheduled = System.Label.CLCEE00017;
        String waitlisted = system.Label.CLCEE00006;
        String interviewed = System.Label.CLCEE00027;
        String withdraw = System.Label.CLCEE00030;
        String lost = System.Label.CLCEE00031;
        String deferredDecision = System.Label.CLCEE00032;
        String withdrew = System.Label.CLCEE00033;
        String rejected = System.Label.CLCEE00034;
        String payment = System.Label.CLCEE00035;
        String offerAccepted = System.Label.CLCEE00016;
        String blockingFee = System.Label.CLCEE00036;
        String proformaInvoice = System.Label.CLCEE00037;
        list<lead> leadsToBeUpdated = New list<lead> ();
        Id leadRecordType = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('ExecEd B2B').getRecordTypeId();
        Id devRecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('ExecEd').getRecordTypeId();
        Id ceeOpenLDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Id ceeOpenSDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-SDP').getRecordTypeId();
        Id ceeHR = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
        set<id> OppIdSet = new set<id>();
        List<Opportunity> listOpp  =  [SELECT Id,Name,StageName,APP_Applicationformstatus__c,RecordTypeId,(Select id,Name,APP_Applicationformstatus__c,RecordTypeId,Opportunity_Stage1__c,Application_status__c,Opportunity_Enrollment_Date__c from Leads__r WHERE RecordTypeId =: devRecordTypeId OR RecordTypeId =: leadRecordType   ORDER BY createdDate) from opportunity WHERE ID IN : mapOpp.keySet()];
        //SELECT Id,Name,(Select id,Name from Leads__r ORDER BY createdDate  ASC LIMIT 1 ) from opportunity 
        for(opportunity opp : listOpp){
            if(opp.RecordTypeId == ceeOpenLDP || opp.RecordTypeId == ceeOpenSDP || opp.RecordTypeId == ceeHr){
                if(Opp.Leads__r != Null){
                    fOR(lead l : Opp.leads__r){
                        if(mapOpp.get(opp.Id).StageName != mapOldOpp.get(opp.Id).StageName && opp.StageName == 'Payment'){
                            l.Opportunity_Enrollment_Date__c = string.valueOf(system.now());
                        }
                        if(opp.APP_Applicationformstatus__c !=null){
                            l.APP_Applicationformstatus__c = opp.APP_Applicationformstatus__c;
                        }    
                        l.Opportunity_Stage1__c = opp.StageName;
                        if(l.Opportunity_Stage1__c == applicationInProgress)
                            l.Application_status__c = 'Application in Progress';
                        else if(l.Opportunity_Stage1__c == applied || l.Opportunity_Stage1__c == offerOpen || l.Opportunity_Stage1__c == interviewsScheduled
                                || l.Opportunity_Stage1__c == waitlisted || l.Opportunity_Stage1__c == interviewed || l.Opportunity_Stage1__c == withdraw ||
                                (l.Opportunity_Stage1__c == lost && opp.APP_Applicationformstatus__c.contains('100')) || (l.Opportunity_Stage1__c == deferredDecision && opp.APP_Applicationformstatus__c.contains('100')) ||
                                (l.Opportunity_Stage1__c == withdrew && opp.APP_Applicationformstatus__c.contains('100')) || (l.Opportunity_Stage1__c == rejected && opp.APP_Applicationformstatus__c.contains('100') )){
                                    l.Application_status__c = 'Application';
                                }
                        else if((l.Opportunity_Stage1__c == lost && !(opp.APP_Applicationformstatus__c.contains('100'))) || (l.Opportunity_Stage1__c == deferredDecision &&!(opp.APP_Applicationformstatus__c.contains('100'))) ||
                                (l.Opportunity_Stage1__c == withdrew && !(opp.APP_Applicationformstatus__c.contains('100'))) || (l.Opportunity_Stage1__c == rejected && !(opp.APP_Applicationformstatus__c.contains('100')))){
                                    l.Application_status__c = 'Opportunity';
                                }
                        else if(l.Opportunity_Stage1__c == payment || l.Opportunity_Stage1__c == offerAccepted || l.Opportunity_Stage1__c == blockingFee || l.Opportunity_Stage1__c == proformaInvoice){
                            l.Application_status__c = 'Enrollment';
                            
                        }
                        leadsToBeUpdated.add(l);
                    }
                    
                }
            }
        }
        if(leadsToBeUpdated.size() > 0){
            update leadsToBeUpdated;
        }
    }
    
    public static void createInvoicesforOpportunity(List<Opportunity> oppList){
        Id devRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Skill Hub').getRecordTypeId();
        Id invrecordTypeId = Schema.SObjectType.CEE_Invoice__c.getRecordTypeInfosByName().get('Skill Hub').getRecordTypeId();
        try{
            for(Opportunity opp:oppList){
                if(opp.RecordTypeId == devRecordTypeId){
                    CEE_Invoice__c inv = new CEE_Invoice__c();
                    inv.Opportunity__c = opp.Id;
                    inv.Payment_Url_New__c = opp.Payment_URL_new__c;
                    inv.PaymentLinkId__c = opp.Payment_Link_Id__c;
                    inv.PaymentSignature__c = opp.Payment_Signature__c;
                    inv.Amount__c = opp.Price__c;
                    inv.Payment_Id__c = opp.Payment_ID__c;
                    inv.RecordTypeId = invrecordTypeId;
                    system.debug('77 :' +inv);
                    insert inv;
                }
            }
        }
        catch(Exception e) {  
            new LogException().Module('CEE Opportunity Trigger Handler Module').log(e);
        }
    }
    

    public Static void UpdateOwnerID(Map<Id ,Opportunity> newMapOpp){
        system.debug('inside');
        Id devRecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('ExecEd').getRecordTypeId();
        Id devRecordTypeId1 = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('ExecEd HFP').getRecordTypeId();
        List<Opportunity> ListopportoBeUpdated = new list<Opportunity>();
        List<Opportunity> listOpp  =  [SELECT Id,Name,StageName,(Select id,ownerID from Leads__r 
                                                                 ORDER BY createdDate  ASC  LIMIT 1  ) from opportunity WHERE id IN:newMapOpp.keySet() ];
        system.debug(listOpp);
        For (Opportunity opp : listOpp){
            if(opp.Leads__r != Null){
                for(lead l : opp.leads__r){
                    opp.ownerID = l.OwnerID;
                    ListopportoBeUpdated.add(opp);
                    
                }
                
            }
        }if(ListopportoBeUpdated.size() >0){
            update ListopportoBeUpdated;
        }
    }
    /*public Static void createopplineitems(Map<Id,Opportunity> newMapOpp,Map<Id,Opportunity> oldMapOpp){
        Id ceeOpenLDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Id ceeOpenSDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-SDP').getRecordTypeId();
        Id ceeHR = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
        Map<Id,List<OpportunityLineItem>> map_LineItemsByOpportunity = new Map<Id,List<OpportunityLineItem>>();
        Map<id,opportunity> mapOppById = new Map<id,opportunity>();
        
        List<OpportunityLineItem> list_opportunityLineItems = [SELECT Id, Name, CEE_PaymentStatus__c,OpportunityId 
                                                               FROM OpportunityLineItem 
                                                               WHERE OpportunityId IN :newMapOpp.keySet()];
        
        if (!list_opportunityLineItems.isEmpty()) {
            for(OpportunityLineItem objLineItem : list_opportunityLineItems){
                if (!map_LineItemsByOpportunity.containsKey(objLineItem.OpportunityId)) {
                    map_LineItemsByOpportunity.put(objLineItem.OpportunityId, new List<OpportunityLineItem>{ objLineItem });
                } else {
                    map_LineItemsByOpportunity.get(objLineItem.OpportunityId).add(objLineItem);
                }
            }
        }
        system.debug('test the map'+ map_LineItemsByOpportunity);
        
        for(Opportunity objOpportunity :newMapOpp.values()) {
            if(objOpportunity.RecordTypeId == ceeOpenLDP || objOpportunity.RecordTypeId == ceeOpenSDP || objOpportunity.RecordTypeId == ceeHr){ 
                if(objOpportunity.StageName =='Payment' && oldMapOpp.get(objOpportunity.Id).StageName =='Applied' && (objOpportunity.APP_NominatedBy__c == 'Sponsored by Company' || objOpportunity.APP_is_HR_Nominated__c == true)){ 
                    if (!map_LineItemsByOpportunity.containsKey(objOpportunity.Id)){
                        system.debug('in the condition');
                        mapOppById.put(objOpportunity.Id,objOpportunity);
                    }
                }
            }
        }
        system.debug(mapOppById.size());
        if(mapOppById.size() > 0)
            createQuotes(mapOppById);   
        
        
    }*/
    
    public static void updateProductCode(List<Opportunity> oppList){
        Set<Id> productIds = new Set<Id>();
        
        // 1. Collect Product IDs from the incoming Opportunities
        for(Opportunity opp : oppList){
            if(opp.APP_Product__c != null){
                productIds.add(opp.APP_Product__c);
            }
        }
        
        if(productIds.isEmpty()){
            return;
        }
        
        // 2. Query Product Details (Included SAP_Internal_Order__c)
        // Optimization: Query into a Map<Id, Product2> to handle bulk records correctly
        Map<Id, Product2> productMap = new Map<Id, Product2>(
            [SELECT Id, ProductCode, Program_Type__c, SAP_Internal_Order__c 
             FROM Product2 
             WHERE Id IN :productIds]
        );
        
        // 3. Loop through Opportunities and update fields
        for(Opportunity opp : oppList){
            // Check if the Opp has a product and if we found it in our query
            if(opp.APP_Product__c != null && productMap.containsKey(opp.APP_Product__c)){
                Product2 relatedProduct = productMap.get(opp.APP_Product__c);
                
                // --- Existing Logic (Preserved) ---
                opp.Product_Code_Tableu__c = relatedProduct.ProductCode;
                opp.Program_Type_Tableau__c = relatedProduct.Program_Type__c;
                
                // --- NEW LOGIC: Stamp IO Number ---
                // Strictly applied only during INSERT as requested
                if(Trigger.isInsert){
                    // Replace 'Opportunity_IO_Number__c' with your actual Opportunity Field API Name
                    opp.Opportunity_IO_Number__c = relatedProduct.SAP_Internal_Order__c;
                }
            }
        }
    }
    
    public static void paxFieldUpdate(List<Opportunity> newOpportunities) {
        Id openLDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
        Id openSDP = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-SDP').getRecordTypeId();
        Id openHR = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
        Map<id,Opportunity> mapContactIdAndOpp = new Map<id,Opportunity>();
        for (Opportunity opp : newOpportunities) {
            if (opp.APP_Contact__c != null && (opp.RecordTypeId == openLDP || opp.RecordTypeId == openSDP ||opp.RecordTypeId == openHR )) {
                mapContactIdAndOpp.put(opp.APP_Contact__c,opp);
                system.debug('mapContactIdAndOpp'+mapContactIdAndOpp);
            }
        }
        
        List<Contact> contactsToUpdate = [SELECT Id,Company__c,Designation__c,Area_of_Expertise__c,year_of_experience__c,Email,MobilePhone,City__c,Salutation__c,Country__c,Current_Postal_Code__c,State__c,Select_Current_Industry__c,Continent__c,PAN_Number__c,GST_Number__c,hed__Gender__c, hed__AlternateEmail__c   FROM Contact WHERE Id IN :mapContactIdAndOpp.keyset()];
        Map<Id, Contact> updatedContacts = new Map<Id, Contact>();
        system.debug('contactsToUpdate'+contactsToUpdate);
        for (Contact con : contactsToUpdate) {
            opportunity opp = mapContactIdAndOpp.get(con.Id);
            if(opp.APP_Company__c != Null ){
                con.Company__c = opp.APP_Company__c;
            }
            if(opp.APP_Designation__c != Null){
                con.Designation__c = opp.APP_Designation__c;
            }
            if(opp.Area_of_Specialisation__c != Null){
                con.Area_of_Expertise__c = opp.Area_of_Specialisation__c;
            }
            
            if(opp.APP_City__c != Null){
                con.City__c = opp.APP_City__c;
            }
            if(opp.APP_State__c != Null){
                con.State__c =opp.APP_State__c;
            }
            if(opp.APP_Country__c != Null){
                con.Country__c = opp.APP_Country__c  ; 
            }
            if(opp.APP_Pincode_New__c != Null){
                con.Current_Postal_Code__c = opp.APP_Pincode_New__c;
            }
            if(opp.APP_CurrentIndustry__c != Null){
                con.Select_Current_Industry__c = Opp.APP_CurrentIndustry__c;
            }
            if(opp.Continent__c != Null){
                con.Continent__c = opp.Continent__c;
            }
            if(opp.APP_Pan__c != Null){
                con.PAN_Number__c = opp.APP_Pan__c;
            }
            
            if(opp.APP_Gender__c != Null){
                con.hed__Gender__c = opp.APP_Gender__c;
            }
            if(opp.APP_Prefix_Nominating__c != Null){
                con.Salutation__c = opp.APP_Prefix_Nominating__c;
            }
            updatedContacts.put(con.Id, con);
        }
        
        if (!updatedContacts.isEmpty()) {
            update updatedContacts.values();
            system.debug('updatedContacts'+updatedContacts);
        }
    } 
    
    @AuraEnabled 
    public static String createParticipantInfoScreen(Id recordId){
        List<CEE_Participant_Info__c> getParticipantInfo = new List<CEE_Participant_Info__c>();
        Opportunity getOpportunity = [Select Id, APP_Contact__c , APP_Email__c , APP_Product__c from Opportunity where Id = :recordId];
        if(getOpportunity.APP_Product__c == null || (getOpportunity.APP_Contact__c == null && getOpportunity.APP_Email__c == null)){
            return 'Invalid';
        }
        else{
            if(getOpportunity.APP_Contact__c != null && getOpportunity.APP_Product__c != null)
                getParticipantInfo = [Select Id from CEE_Participant_Info__c where Contact_Name__c = :getOpportunity.APP_Contact__c AND Program_Name__c=:getOpportunity.APP_Product__c];
            else
                getParticipantInfo = [Select Id from CEE_Participant_Info__c where Contact_Email_Id__c = :getOpportunity.APP_Email__c AND Program_Name__c=:getOpportunity.APP_Product__c];
            
            if( getParticipantInfo.size() > 0 ){
                return 'Present';
            }
            else{
                CEE_Participant_Info__c createParticipantInfo = new CEE_Participant_Info__c();
                createParticipantInfo.Program_Name__c = getOpportunity.APP_Product__c;
                if(getOpportunity.APP_Contact__c != null)
                    createParticipantInfo.Contact_Name__c = getOpportunity.APP_Contact__c;
                else
                    createParticipantInfo.Contact_Email_Id__c = getOpportunity.APP_Email__c;
                
                insert createParticipantInfo;
                return 'Created';
            }
        }
    }
    public static void sendAttachments(List<Opportunity> lstOpportunity, Map<Id, Opportunity> opportunityOldMap){
        Id grantsRecordTypeIdForOpportunity = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get(System.Label.GrantsRecordTypeName).getRecordTypeId();
        List<Opportunity> oppList = new List<Opportunity>();
        List<Opportunity> oppFacultyList = new List<Opportunity>();
        List<Id> gmacId = new List<id>();
        for(Opportunity oppRec : lstOpportunity){
            Opportunity oldOpp = opportunityOldMap.get(oppRec.Id);
            if((oppRec.Docsign_Completed__c !=oldOpp.Docsign_Completed__c)&&(oppRec.Docsign_Completed__c ==True) && (oppRec.RecordTypeId == grantsRecordTypeIdForOpportunity)){
                oppList.add(oppRec);
            }
            
            if(oppRec.StageName != oldOpp.StageName && oppRec.StageName == 'Grant agreement approved on DocuSign'&& (oppRec.RecordTypeId == grantsRecordTypeIdForOpportunity)){
                oppFacultyList.add(oppRec);
            }
            
            if(oppRec.RecordTypeId == grantsRecordTypeIdForOpportunity && (oppRec.GMAC_Chair_Approved__c != true && oppRec.GMAC_Chair_Rejected__c !=True) && oppRec.FCRA_NON_FCRA__c != oldOpp.FCRA_NON_FCRA__c &&
               ((oppRec.FCRA_NON_FCRA__c == 'FCRA' && oppRec.Overhead_charges__c <20.0 && opprec.Justification__c != Null) || (oppRec.FCRA_NON_FCRA__c == 'Non-FCRA' && oppRec.Overhead_charges__c <30.0 && opprec.Justification__c != Null))){
                   gmacId.add(oppRec.Id);
               }
            
        }
        if(oppList.size()>0){
            OpportunityTriggerHandleGrants.sendAttachmentsToGrants(oppList);
        }
        
        if(oppFacultyList.size()>0){
            OpportunityTriggerHandleGrants.sendAttachmentsToFaculty(oppFacultyList);
        }
        
        if(gmacId.size()>0){
            //OpportunityTriggerHandleGrants.sendEmailToGMAC(gmacId);
        }
        
    }
    
    @future
    public static void updateUTMParameters(List<Id> oppIds){
        List<Opportunity> oppList = [Select Id , Mode_of_travel_to_ISB__c,APP_Contact__c,UTM_Campaign__c,UTM_Content__c,UTM_Medium__c,UTM_Source__c,UTM_Term__c from Opportunity where Id IN :oppIds];
        Map<Id,Contact> map_IdsByContact = new Map<Id,Contact>();
        List<Id> contactIds = new List<Id>();
        for(Opportunity opp : oppList){
            contactIds.add(opp.APP_Contact__c);
        }
        List<Contact> contactList = [Select Id,Mode_of_travel_to_ISB__c,UTM_Campaign__c,UTM_Content__c,UTM_Medium__c,UTM_Source__c,UTM_Term__c,isChecked__c FROM Contact WHERE Id IN : contactIds];
        if(contactList.size()>0){
            for(Contact con : contactList){
                map_IdsByContact.put(con.Id,con);
            }
        }
        String mode;
        for(Opportunity opp : oppList){
            mode = opp.Mode_of_travel_to_ISB__c;
            if(opp.APP_Contact__c != null){
                Contact getContact = map_IdsByContact.get(opp.APP_Contact__c);
                if(getContact.isChecked__c == false && (getContact.UTM_Campaign__c!=NULL || getContact.UTM_Content__c!=NULL || getContact.UTM_Medium__c!=NULL || getContact.UTM_Source__c!=NULL || getContact.UTM_Term__c!=NULL)){
                    if(opp.UTM_Campaign__c == NULL && opp.UTM_Content__c == NULL && opp.UTM_Medium__c == NULL && opp.UTM_Source__c == NULL && opp.UTM_Term__c == NULL){
                        opp.UTM_Campaign__c = getContact.UTM_Campaign__c;
                        opp.UTM_Content__c = getContact.UTM_Content__c;
                        opp.UTM_Medium__c = getContact.UTM_Medium__c;
                        opp.UTM_Source__c = getContact.UTM_Source__c;
                        opp.UTM_Term__c = getContact.UTM_Term__c;
                    }
                    else {
                        createUTMHistoryRecords(opp.Id);
                        opp.UTM_Campaign__c = getContact.UTM_Campaign__c;
                        opp.UTM_Content__c = getContact.UTM_Content__c;
                        opp.UTM_Medium__c = getContact.UTM_Medium__c;
                        opp.UTM_Source__c = getContact.UTM_Source__c;
                        opp.UTM_Term__c = getContact.UTM_Term__c;
                    }
                }
            }
        }
        for(Contact con:contactList){
            con.Mode_of_travel_to_ISB__c = mode;
            con.isChecked__c = true;
            /*con.UTM_Campaign__c = null;
con.UTM_Content__c = null;
con.UTM_Medium__c = null;
con.UTM_Source__c = null;
con.UTM_Term__c = null;
con.Locale__c = null;*/
        }
        if(contactList.size() >0){
            update contactList;
        }
        if(oppList.size() > 0){
            update oppList;
        }
    }
    
    public static void createUTMHistoryRecords(Id oppId){
        Boolean flag = false;
        Opportunity opp = [Select Id,UTM_Campaign__c,UTM_Content__c,UTM_Medium__c,UTM_Source__c,UTM_Term__c From Opportunity Where Id =:oppId];
        List<Opportunity_UTM_History__c> utmList = [Select Id,Opportunity__c From Opportunity_UTM_History__c where Opportunity__c =:oppId];
        if(utmList.size() == 0){
            flag = true;
        }
        Opportunity_UTM_History__c utmHistory = new Opportunity_UTM_History__c();
        utmHistory.UTM_Campaign__c = opp.UTM_Campaign__c;
        utmHistory.UTM_Content__c = opp.UTM_Content__c;
        utmHistory.UTM_Medium__c = opp.UTM_Medium__c;
        utmHistory.UTM_Source__c = opp.UTM_Source__c;
        utmHistory.UTM_Term__c = opp.UTM_Term__c;
        utmHistory.Opportunity__c = opp.Id;
        //System.debug('utmList.size'+utmList.size());
        //Integer utmSize = utmList.size() + 1;
        utmHistory.Name = 'UTM - '+String.valueOf(utmList.size() + 1);
        //System.debug('UTM Name'+utmHistory.Name);
        if(flag == true){
            utmHistory.isFirst__c = true;
        }
        insert utmHistory;
    }
    
    public static void copyRemarksToRemarksTableu(List<Opportunity> opportunities) {
        for (Opportunity opp : opportunities) {
            if (opp.Description != null) {
                opp.Remarks_Tableau_c__c = opp.Description.substring(0, Math.min(255, opp.Description.length()));
            } else {
                opp.Remarks_Tableau_c__c = null;
            }
        }
    }
    
    
    public static void recalculateConvertedOpps(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        
        Set<Id> ownerIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();

        // 1. Collect affected owners and products.
        // We only run if the Stage, Owner, or Product has changed.
        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldOppMap.get(opp.Id);

            // Check if the opp just became a 'Student'
            boolean stageChangedToStudent = (opp.StageName == 'Student' && oldOpp.StageName != 'Student');
            
            // Check if the opp is no longer a 'Student' (to decrement the count)
            boolean stageChangedFromStudent = (opp.StageName != 'Student' && oldOpp.StageName == 'Student');
            
            // Check if owner or product changed
            boolean ownerChanged = (opp.OwnerId != oldOpp.OwnerId);
            
            // *** Using your custom product field ***
            boolean productChanged = (opp.APP_Product__c != oldOpp.APP_Product__c); 

            // If any relevant field changed, we need to recalculate
            if (stageChangedToStudent || stageChangedFromStudent || ownerChanged || productChanged) {
                
                // Add *both* new and old owners/products to ensure
                // we recalculate for all affected targets.
                if (opp.OwnerId != null) ownerIds.add(opp.OwnerId);
                if (oldOpp.OwnerId != null) ownerIds.add(oldOpp.OwnerId);
                
                if (opp.APP_Product__c != null) productIds.add(opp.APP_Product__c);
                if (oldOpp.APP_Product__c != null) productIds.add(oldOpp.APP_Product__c);
            }
        }

        // If no relevant changes, exit
        if (ownerIds.isEmpty() || productIds.isEmpty()) {
            return; 
        }

        // 2. Get all targets for the affected owners and products.
        List<Lead_Targets__c> allTargetsForOwners = [
            SELECT Id, BD_Owner__c, Product__c, Total_Converted_Leads__c
            FROM Lead_Targets__c 
            WHERE BD_Owner__c IN :ownerIds
              AND Product__c IN :productIds
        ];

        if (allTargetsForOwners.isEmpty()) {
            return;
        }

        Map<String, Integer> achievedCounts = new Map<String, Integer>();
        
        for (AggregateResult ar : [
            SELECT COUNT(Id) total, OwnerId, APP_Product__c 
            FROM Opportunity 
            WHERE OwnerId IN :ownerIds 
              AND APP_Product__c IN :productIds
              AND StageName = 'Student' 
            GROUP BY OwnerId, APP_Product__c
        ]) {
            // We only care about Opps that have a product
            if (ar.get('APP_Product__c') != null) {
                // Key is 'OwnerId-ProductId'
                String key = (Id)ar.get('OwnerId') + '-' + (Id)ar.get('APP_Product__c');
                achievedCounts.put(key, (Integer)ar.get('total'));
            }
        }

        // 4. Loop through targets and update *only* the converted count
        List<Lead_Targets__c> targetsToUpdate = new List<Lead_Targets__c>();
        for (Lead_Targets__c target : allTargetsForOwners) {
            
            if (target.Product__c == null) continue; 
            
            String key = target.BD_Owner__c + '-' + target.Product__c;
            
            // Get the new count, defaulting to 0 if none found
            Integer newAchievedCount = achievedCounts.containsKey(key) ? achievedCounts.get(key) : 0;
            
            // Only update if the value has *actually* changed to avoid DML
            if (target.Total_Converted_Leads__c != newAchievedCount) {
                target.Total_Converted_Leads__c = newAchievedCount;
                targetsToUpdate.add(target);
            }
        }

        if (!targetsToUpdate.isEmpty()) {
            update targetsToUpdate;
        }
    } 
    
    public static void handleRemarksUpdate(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        for (Opportunity newOpp : newOpps) {
            Opportunity oldOpp = oldOppMap.get(newOpp.Id);
            if (newOpp.Description != oldOpp.Description) {
                newOpp.Remarks_Last_Modified__c = System.now();
            }
        }
    }
    
        /**
     * @author      :    Monika Choudhary
     * @description :    Create single OpportunityLineItem when stage changes to 'Offer Open'
     *                   Uses Product and Pricebook from Opportunity
     *                   OPTIMIZED: All SOQL queries moved outside loops
     * @param       :    mapOppById - Map of Opportunities by Id
     * @return      :    void
     */
    
    /*
    public static void createOLIsFromOpportunity(Map<Id, Opportunity> mapOppById) {
        if (mapOppById == null || mapOppById.isEmpty()) return;

        Set<Id> productIds = new Set<Id>();
        Set<Id> pricebookIds = new Set<Id>();
        Map<Id, Opportunity> oppToCreateOlis = new Map<Id, Opportunity>();
        List<String> listRecordReference = new List<String>();

        try{

        for (Opportunity opp : mapOppById.values()) {
            listRecordReference.add(opp.Id);
            if (opp.APP_Product__c != null && opp.Pricebook2Id != null) {
                oppToCreateOlis.put(opp.Id, opp);
                productIds.add(opp.APP_Product__c);
                pricebookIds.add(opp.Pricebook2Id);
            }
        }

        if (oppToCreateOlis.isEmpty()) return;

            // 1. Query PricebookEntries
            Map<String, PricebookEntry> pbeMap = new Map<String, PricebookEntry>(); 
            List<PricebookEntry> pbes = [
                SELECT Id, Product2Id, Pricebook2Id, UnitPrice, IsActive, Discount_in_Percentage__c,Total_Price_After_Discount__c
                FROM PricebookEntry
                WHERE Product2Id IN :productIds
                AND Pricebook2Id IN :pricebookIds
                AND IsActive = true
            ];

            for (PricebookEntry p : pbes) {
                pbeMap.put(String.valueOf(p.Pricebook2Id) + '|' + String.valueOf(p.Product2Id), p);
            }

            // 2. Query Product fields (GST_Percentage__c is now treated as a Number)
            Map<Id, Product2> productsMap = new Map<Id, Product2>([
                SELECT Id, Name, Family, Start_Date__c, Description, CanUseRevenueSchedule,
                    Installment_Distribution__c,       
                    Installment_Due_Date_Structure__c,
                    GST_Applicable__c,
                    GST__c      
                FROM Product2
                WHERE Id IN :productIds
            ]);

            // Check for existing OLIs
            Map<String, OpportunityLineItem> existingOlisMap = new Map<String, OpportunityLineItem>();
            for (OpportunityLineItem existingOli : [
                SELECT Id, OpportunityId, Product2Id
                FROM OpportunityLineItem
                WHERE OpportunityId IN :oppToCreateOlis.keySet()
                AND Product2Id IN :productIds
            ]) {
                String key = existingOli.OpportunityId + '-' + existingOli.Product2Id;
                existingOlisMap.put(key, existingOli);
            }

            List<OpportunityLineItem> olisToInsert = new List<OpportunityLineItem>();

            // 3. Create OLIs
            for (Id oppId : oppToCreateOlis.keySet()) {
                Opportunity opp = oppToCreateOlis.get(oppId);
                Product2 product = productsMap.get(opp.APP_Product__c);

                if (product == null) continue;

                String key = oppId + '-' + product.Id;
                if (existingOlisMap.containsKey(key)) {
                    continue;
                }

                OpportunityLineItem oli = new OpportunityLineItem();
                oli.OpportunityId = oppId;
                oli.Product2Id = product.Id;
                oli.Quantity = 1;

                String pbeKey = String.valueOf(opp.Pricebook2Id) + '|' + String.valueOf(product.Id);
                
                if (pbeMap.containsKey(pbeKey)) {
                    PricebookEntry pbe = pbeMap.get(pbeKey);
                    oli.PricebookEntryId = pbe.Id;
                    oli.UnitPrice = pbe.Total_Price_After_Discount__c;
                    oli.Discount = pbe.Discount_in_Percentage__c;
                } else {
                    continue; 
                }
                oli.Description = product.Description;
                olisToInsert.add(oli);
            }

            if (!olisToInsert.isEmpty()) {
                insert olisToInsert;

                // ---------------------------------------------------------
                // 4. SCHEDULE LOGIC (Number Field Adjustment)
                // ---------------------------------------------------------
                
                List<OpportunityLineItem> olisNeedingCustomSchedule = new List<OpportunityLineItem>();
                Set<Id> oliIdsToOverride = new Set<Id>();

                for (OpportunityLineItem oli : olisToInsert) {
                    Product2 prod = productsMap.get(oli.Product2Id);
                    if (prod != null && String.isNotBlank(prod.Installment_Distribution__c)) {
                        olisNeedingCustomSchedule.add(oli);
                        oliIdsToOverride.add(oli.Id);
                    }
                }

                if (!oliIdsToOverride.isEmpty()) {
                    List<OpportunityLineItemSchedule> schedulesToDelete = [
                        SELECT Id FROM OpportunityLineItemSchedule 
                        WHERE OpportunityLineItemId IN :oliIdsToOverride
                    ];
                    if (!schedulesToDelete.isEmpty()) {
                        delete schedulesToDelete;
                    }
                }

                List<OpportunityLineItemSchedule> schedulesToInsert = new List<OpportunityLineItemSchedule>();

                for (OpportunityLineItem oli : olisNeedingCustomSchedule) {
                    Product2 prod = productsMap.get(oli.Product2Id);
                    
                    String distRaw = prod.Installment_Distribution__c.removeStart('INST-');
                    List<String> distParts = distRaw.split(';');
                    
                    List<String> dateParts = new List<String>();
                    if(String.isNotBlank(prod.Installment_Due_Date_Structure__c)){
                        dateParts = prod.Installment_Due_Date_Structure__c.removeStart('D-').split(';');
                    }

                    // --- GST PREPARATION (NUMBER LOGIC) ---
                    Decimal gstNumberValue = 0; 
                    if (prod.GST_Applicable__c == true && prod.GST__c != null) {
                        // e.g., value is 18
                        gstNumberValue = prod.GST__c; 
                    }

                    for (Integer i = 0; i < distParts.size(); i++) {
                        Decimal installmentPercent = Decimal.valueOf(distParts[i]);
                        
                        OpportunityLineItemSchedule sch = new OpportunityLineItemSchedule();
                        sch.OpportunityLineItemId = oli.Id;
                        sch.Installment_Number__c = i + 1;
                        sch.Type = System.Label.Type_Revenue;
                        sch.Payment_Status__c = System.Label.Status_NotPaid;
                        
                        if (oli.UnitPrice != null) {
                            // 1. Calculate Base Amount (Installment Share)
                            Decimal baseAmount = (installmentPercent / 100) * oli.UnitPrice;
                            sch.Base_Amount__c = baseAmount;
                            
                            // 2. Store the Raw Number (e.g., 18)
                            sch.GST__c = gstNumberValue; 

                            // 3. Calculate GST Amount
                            // Since gstNumberValue is "18", we must divide by 100 here
                            Decimal gstAmount = baseAmount * (gstNumberValue / 100);
                            
                            // 4. Set Total Revenue (Base + Tax)
                            sch.Revenue = baseAmount + gstAmount;
                        }

                        // Date Logic
                        if (i == 0) {
                            if (prod.Start_Date__c != null) {
                                sch.ScheduleDate = prod.Start_Date__c.addDays(-1);
                            } else {
                                sch.ScheduleDate = System.today().addDays(1);
                            }
                        } else {
                            Integer dateIndex = i - 1;
                            if (dateIndex < dateParts.size()) {
                                Integer dayOffset = Integer.valueOf(dateParts[dateIndex]);
                                if (prod.Start_Date__c != null) {
                                    sch.ScheduleDate = prod.Start_Date__c.addDays(dayOffset);
                                } else {
                                    sch.ScheduleDate = System.today().addDays(dayOffset);
                                }
                            } else {
                                sch.ScheduleDate = System.today().addDays(30 * i);
                            }
                        }
                        schedulesToInsert.add(sch);
                    }
                }

                if (!schedulesToInsert.isEmpty()) {
                    insert schedulesToInsert;
                }

                // Send Open Offer Email for first schedule if Opportunity has contact
                // Set<Id> offerOpenOppIds = new Set<Id>();
                // for (Opportunity opp : mapOppById.values()) {
                //     if (opp.APP_Contact__c != null) {
                //         offerOpenOppIds.add(opp.Id);
                //     }
                // }
                // if (!offerOpenOppIds.isEmpty()) {
                //     // Query OLIs for offer open opportunities
                //     Map<Id, Id> oppIdToOliId = new Map<Id, Id>();
                //     List<OpportunityLineItem> olis = [
                //         SELECT Id, OpportunityId 
                //         FROM OpportunityLineItem 
                //         WHERE OpportunityId IN :offerOpenOppIds
                //     ];
                //     for (OpportunityLineItem oli : olis) {
                //         oppIdToOliId.put(oli.OpportunityId, oli.Id);
                //     }
                //     // Query schedules for those OLIs, ordered by ScheduleDate
                //     Map<Id, OpportunityLineItemSchedule> oliIdToFirstSchedule = new Map<Id, OpportunityLineItemSchedule>();
                //     List<OpportunityLineItemSchedule> schedules = [
                //         SELECT Id, Payment_Link__c, ScheduleDate, OpportunityLineItemId 
                //         FROM OpportunityLineItemSchedule 
                //         WHERE OpportunityLineItemId IN :oppIdToOliId.values() 
                //         ORDER BY OpportunityLineItemId, ScheduleDate ASC
                //     ];
                //     for (OpportunityLineItemSchedule sch : schedules) {
                //         if (!oliIdToFirstSchedule.containsKey(sch.OpportunityLineItemId)) {
                //             oliIdToFirstSchedule.put(sch.OpportunityLineItemId, sch);
                //         }
                //     }
                    // Now process each offer open opportunity
                    // List<EE_DL_SendEmailForOpenOffer.FlowInput> emailRequests = new List<EE_DL_SendEmailForOpenOffer.FlowInput>();
                    // for (Id oppId : offerOpenOppIds) {
                    //     Id oliId = oppIdToOliId.get(oppId);
                    //     if (oliId != null) {
                    //         OpportunityLineItemSchedule sch = oliIdToFirstSchedule.get(oliId);
                    //         if (sch != null) {
                    //             Opportunity opp = mapOppById.get(oppId);
                    //             // Generate payment link if missing and schedule date is in future
                    //             if (sch.Payment_Link__c == null && sch.ScheduleDate >= Date.today()) {
                    //                 EE_DL_RazorPay_FlowWrapper.Request req = new EE_DL_RazorPay_FlowWrapper.Request();
                    //                 req.scheduleId = sch.Id;
                    //                 List<EE_DL_RazorPay_FlowWrapper.Response> responses = EE_DL_RazorPay_FlowWrapper.generateLink(new List<EE_DL_RazorPay_FlowWrapper.Request>{req});
                    //                 // Assuming the method updates the Payment_Link__c on the schedule record
                    //             }
                                // Prepare the email request
                                // EE_DL_SendEmailForOpenOffer.FlowInput emailReq = new EE_DL_SendEmailForOpenOffer.FlowInput();
                                // emailReq.contactId = opp.APP_Contact__c;
                                // emailReq.opportunityId = opp.Id;
                                // emailReq.scheduleId = sch.Id;
                                // emailReq.templateName = 'Offer_Open_Payment_Link_HTML';
                                // emailRequests.add(emailReq);
                    //         }
                    //     }
                    // }
                    // Send all emails in bulk
                    // if (!emailRequests.isEmpty()) {
                    //     EE_DL_SendEmailForOpenOffer.sendEmail(emailRequests);
                    // }
                // }
            }

        } catch (Exception ex) {
            ErrorLogHandler.createLog('CEE_OpportunityTriggerHandler.createOLIsFromOpportunity()', 'Apex Class', ex, String.join(listRecordReference, ', '), null, null);     
        }

    }
    */
    
    public static void sendOfferLetterEmail(Set<Id> oppIds){

        if(oppIds == null || oppIds.isEmpty()){
            return;
        }

        /* -------------------------------------------------
        STEP 1 — Get Opportunities
        --------------------------------------------------- */

        List<Opportunity> oppList = [
            SELECT Id,
                APP_Contact__c,
                Opportunity_Type__c,
                Sub_Stage__c,
                BillingInfo_Submitted__c,
                StageName,
                Owner.Email
            FROM Opportunity
            WHERE Id IN :oppIds
        ];

        if(oppList.isEmpty()){
            return;
        }

        /* -------------------------------------------------
        STEP 2 — Get Email Templates
        --------------------------------------------------- */

        Map<String, Id> templateMap = new Map<String, Id>();

        for(EmailTemplate et : [
            SELECT Id, DeveloperName
            FROM EmailTemplate
            WHERE DeveloperName IN ('B2C2B_Request','B2C2B_Billing_Info_Request')
        ]){
            templateMap.put(et.DeveloperName, et.Id);
        }

        Id b2c2bTemplate = templateMap.get('B2C2B_Request');
        Id b2cTemplate = templateMap.get('B2C2B_Billing_Info_Request');

        /* -------------------------------------------------
        STEP 3 — Get OrgWideEmailAddress
        --------------------------------------------------- */

        Id orgWideEmailId = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = 'execed@isb.edu'
            LIMIT 1
        ].Id;

        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

        /* -------------------------------------------------
        STEP 4 — Process Opportunities
        --------------------------------------------------- */


        for(Opportunity opp : oppList){

            if(opp.APP_Contact__c == null){
                continue;
            }

            /* -------- Generate Offer Letter PDF -------- */

            EE_DL_GenerateOfferLetterPDF.Request req = new EE_DL_GenerateOfferLetterPDF.Request();
            req.opportunityId = opp.Id;

            List<EE_DL_GenerateOfferLetterPDF.Response> pdfResponse =
                EE_DL_GenerateOfferLetterPDF.generatePDF(
                    new List<EE_DL_GenerateOfferLetterPDF.Request>{req}
                );

            String contentVersionId;

            if(!pdfResponse.isEmpty()){
                contentVersionId = pdfResponse[0].contentVersionId;
            }

            /* -------- Determine Template (same logic as Flow) -------- */

            Id templateId;

            if( (opp.Opportunity_Type__c == 'B2C' || (opp.Opportunity_Type__c == 'B2C2B' && opp.Sub_Stage__c != 'Company Payment')) && opp.StageName == 'Offer Open' )
            {
                templateId = b2cTemplate;
            }

            else if( opp.Opportunity_Type__c == 'B2C2B'  && opp.Sub_Stage__c == 'Company Payment' && opp.StageName == 'Offer Open' ){
                templateId = b2c2bTemplate;
            }

            if(templateId == null){
                continue;
            }

            /* -------- Send Email -------- */

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            // --- DYNAMIC CC LOGIC (from Custom Label) ---
            String appSupportCc = Label.App_Support_Email;
            List<String> currentCc = new List<String>();
            if (String.isNotBlank(appSupportCc)) currentCc.add(appSupportCc);
            if (opp.Owner.Email != null) {
                currentCc.add(opp.Owner.Email); // Add the BD Owner to CC
            }
            if (!currentCc.isEmpty()) mail.setCcAddresses(currentCc);
            // -------------------------

            mail.setTemplateId(templateId);
            mail.setTargetObjectId(opp.APP_Contact__c);
            mail.setWhatId(opp.Id);
            mail.setOrgWideEmailAddressId(orgWideEmailId);
            mail.setSaveAsActivity(true);

            if(contentVersionId != null){
                mail.setEntityAttachments(new List<String>{contentVersionId});
            }

            emailList.add(mail);
        }

        if(!emailList.isEmpty()){
            Messaging.sendEmail(emailList);
        }
    }
    
    public static void createOLIsFromOpportunity(Map<Id, Opportunity> mapOppById) {
        if (mapOppById == null || mapOppById.isEmpty()) return;
        
        Set<Id> productIds = new Set<Id>();
        Set<Id> pricebookIds = new Set<Id>();
        Map<Id, Opportunity> oppToCreateOlis = new Map<Id, Opportunity>();
        List<String> listRecordReference = new List<String>();
        
        
        try {
            for (Opportunity opp : mapOppById.values()) {
                // Filter out irrelevant records
                if (opp.APP_is_HR_Nominated__c == true || opp.Opportunity_Type__c == 'B2B') {
                    continue; 
                }
                listRecordReference.add(opp.Id);
                if (opp.APP_Product__c != null && opp.Pricebook2Id != null) {
                    oppToCreateOlis.put(opp.Id, opp);
                    productIds.add(opp.APP_Product__c);
                    pricebookIds.add(opp.Pricebook2Id);
                }
            }
            
            if (oppToCreateOlis.isEmpty()) return;
            
            // 1. Query PricebookEntries
            Map<String, PricebookEntry> pbeMap = new Map<String, PricebookEntry>(); 
            List<PricebookEntry> pbes = [
                SELECT Id, Product2Id, Pricebook2Id, UnitPrice, IsActive, Discount_in_Percentage__c, Total_Price_After_Discount__c
                FROM PricebookEntry
                WHERE Product2Id IN :productIds
                AND Pricebook2Id IN :pricebookIds
                AND IsActive = true
            ];
            
            for (PricebookEntry p : pbes) {
                pbeMap.put(String.valueOf(p.Pricebook2Id) + '|' + String.valueOf(p.Product2Id), p);
            }
            
            // 2. Query Product fields
            Map<Id, Product2> productsMap = new Map<Id, Product2>([
                SELECT Id, Name, Family, Start_Date__c, Description, CanUseRevenueSchedule,
                Installment_Distribution__c,        
                Installment_Due_Date_Structure__c,
                GST_Applicable__c,
                GST__c      
                FROM Product2
                WHERE Id IN :productIds
            ]);
            
            // Check for existing OLIs
            Map<String, OpportunityLineItem> existingOlisMap = new Map<String, OpportunityLineItem>();
            for (OpportunityLineItem existingOli : [
                SELECT Id, OpportunityId, Product2Id
                FROM OpportunityLineItem
                WHERE OpportunityId IN :oppToCreateOlis.keySet()
                AND Product2Id IN :productIds
            ]) {
                String key = existingOli.OpportunityId + '-' + existingOli.Product2Id;
                existingOlisMap.put(key, existingOli);
            }
            
            
            List<OpportunityLineItem> olisToInsert = new List<OpportunityLineItem>();
            
            // 3. Create OLIs
            for (Id oppId : oppToCreateOlis.keySet()) {
                Opportunity opp = oppToCreateOlis.get(oppId);
                Product2 product = productsMap.get(opp.APP_Product__c);
                
                if (product == null) continue;
                
                String key = oppId + '-' + product.Id;
                if (existingOlisMap.containsKey(key)) continue; 
                
                OpportunityLineItem oli = new OpportunityLineItem();
                oli.OpportunityId = oppId;
                oli.Product2Id = product.Id;
                oli.Quantity = 1;
                
                String pbeKey = String.valueOf(opp.Pricebook2Id) + '|' + String.valueOf(product.Id);
                
                if (pbeMap.containsKey(pbeKey)) {
                    PricebookEntry pbe = pbeMap.get(pbeKey);
                    oli.PricebookEntryId = pbe.Id;
                    oli.UnitPrice = pbe.Total_Price_After_Discount__c; 
                    oli.Discount = pbe.Discount_in_Percentage__c;
                } else {
                    continue; 
                }
                oli.Description = product.Description;
                olisToInsert.add(oli);
            }
            
            
            
            if (!olisToInsert.isEmpty()) {
                insert olisToInsert;
                
                List<OpportunityLineItem> olisNeedingCustomSchedule = new List<OpportunityLineItem>();
                Set<Id> oliIdsToOverride = new Set<Id>();
                
                for (OpportunityLineItem oli : olisToInsert) {
                    Product2 prod = productsMap.get(oli.Product2Id);
                    if (prod != null && String.isNotBlank(prod.Installment_Distribution__c)) {
                        olisNeedingCustomSchedule.add(oli);
                        oliIdsToOverride.add(oli.Id);
                    }
                }
                
                if (!oliIdsToOverride.isEmpty()) {
                    List<OpportunityLineItemSchedule> schedulesToDelete = [
                        SELECT Id FROM OpportunityLineItemSchedule 
                        WHERE OpportunityLineItemId IN :oliIdsToOverride
                    ];
                    if (!schedulesToDelete.isEmpty()) {
                        delete schedulesToDelete;
                    }
                }
                
                List<OpportunityLineItemSchedule> schedulesToInsert = new List<OpportunityLineItemSchedule>();
                
                for (OpportunityLineItem oli : olisNeedingCustomSchedule) {
                    Product2 prod = productsMap.get(oli.Product2Id);
                    Opportunity opp = oppToCreateOlis.get(oli.OpportunityId);
                    
                    String pbeKey = String.valueOf(opp.Pricebook2Id) + '|' + String.valueOf(prod.Id);
                    PricebookEntry pbe = pbeMap.get(pbeKey);
                    
                    if(pbe == null) continue;
                    
                    // --- 1. SETUP DISTRIBUTION & DATES ---
                    String distRaw = prod.Installment_Distribution__c.removeStart('INST-');
                    List<String> distParts = distRaw.split(';');
                    
                    List<String> dateParts = new List<String>();
                    if(String.isNotBlank(prod.Installment_Due_Date_Structure__c)){
                        dateParts = prod.Installment_Due_Date_Structure__c.removeStart('D-').split(';');
                    }
                    
                    // --- 2. PERCENTAGE CALCULATIONS ---
                    // Get Total Discount % from PBE (e.g., 30.0)
                    Decimal totalDiscountPercent = (pbe.Discount_in_Percentage__c != null) ? pbe.Discount_in_Percentage__c : 0;
                    
                    // Arrays to store per-installment values
                    Decimal[] distributionPercents = new Decimal[distParts.size()];
                    Decimal[] scheduleDiscountPercents = new Decimal[distParts.size()];
                    
                    // Parse distribution percents (e.g., 50, 25, 25)
                    for(Integer i = 0; i < distParts.size(); i++) {
                        distributionPercents[i] = Decimal.valueOf(distParts[i]);
                    }
                    
                    // Reverse Waterfall Logic using PERCENTAGES
                    Decimal remainingDiscountPercent = totalDiscountPercent;
                    
                    for(Integer i = distParts.size() - 1; i >= 0; i--) {
                        if(remainingDiscountPercent <= 0) {
                            scheduleDiscountPercents[i] = 0;
                            continue;
                        }
                        
                        if(distributionPercents[i] >= remainingDiscountPercent) {
                            // Installment can absorb the remaining discount completely
                            scheduleDiscountPercents[i] = remainingDiscountPercent;
                            remainingDiscountPercent = 0;
                        } else {
                            // Discount is larger than this installment; absorb full distribution % and carry over
                            scheduleDiscountPercents[i] = distributionPercents[i];
                            remainingDiscountPercent = remainingDiscountPercent - distributionPercents[i];
                        }
                    }
                    
                    // --- 3. CREATE SCHEDULES ---
                    Decimal listPrice = pbe.UnitPrice; // Total Product Price (Undiscounted)
                    Decimal gstRate = 0; 

                    Boolean isSez = (opp.APP_HasSEZCertificate__c == true);

                    if (opp.APP_Citizeship__c == 'India' && !isSez) {
                        if (prod.GST_Applicable__c == true && prod.GST__c != null) {
                            gstRate = prod.GST__c; 
                        }
                    }
                    
                    for (Integer i = 0; i < distParts.size(); i++) {
                        OpportunityLineItemSchedule sch = new OpportunityLineItemSchedule();
                        sch.OpportunityLineItemId = oli.Id;
                        sch.Installment_Number__c = i + 1;
                        sch.Type = System.Label.Type_Revenue;
                        
                        // Retrieve calculated percentages
                        Decimal distPercent = distributionPercents[i];
                        Decimal discountPercentForSch = scheduleDiscountPercents[i];
                        
                        // Calculate Amounts based on Total List Price
                        Decimal baseAmount = listPrice * (distPercent / 100);
                        Decimal discountAmount = listPrice * (discountPercentForSch / 100);
                        Decimal netAmount = baseAmount - discountAmount;
                        
                        // A. Base Amount (Gross Share)
                        // Base_Amount__c is formula/non-writable in the deployed org shape.
                        // Keep the existing UAT behavior and do not attempt DML into it.
                        // sch.Base_Amount__c = baseAmount;
                        
                        // B. Discount Amount (Value)
                        sch.Discounted_Amount__c = discountAmount;
                        
                        // C. Discount Percentage (The Absolute % requested)
                        // If Dist is 25% and we discount fully, this shows 25% (not 100%)
                        sch.Discount__c = discountPercentForSch; 
                        
                        // D. GST & Revenue (Calculated on Net)
                        Decimal gstAmount = netAmount * (gstRate / 100);
                        sch.GST__c = gstRate;
                        sch.Revenue = netAmount + gstAmount;
                        
                        // Payment Status Logic
                        if(sch.Revenue <= 0) {
                            sch.Payment_Status__c = 'Paid';
                        } else {
                            sch.Payment_Status__c = System.Label.Status_NotPaid;
                        }
                        
                        // Date Logic
                        if (i == 0) {
                            if (prod.Start_Date__c != null) {
                                sch.ScheduleDate = prod.Start_Date__c.addDays(-1);
                            } else {
                                sch.ScheduleDate = System.today().addDays(1);
                            }
                        } else {
                            Integer dateIndex = i - 1;
                            if (dateIndex < dateParts.size()) {
                                Integer dayOffset = Integer.valueOf(dateParts[dateIndex]);
                                if (prod.Start_Date__c != null) {
                                    sch.ScheduleDate = prod.Start_Date__c.addDays(dayOffset);
                                } else {
                                    sch.ScheduleDate = System.today().addDays(dayOffset);
                                }
                            } else {
                                sch.ScheduleDate = System.today().addDays(30 * i);
                            }
                        }
                        schedulesToInsert.add(sch);
                    }
                }
                
                
                if (!schedulesToInsert.isEmpty()) {
                    insert schedulesToInsert;
                }
            }
            
        } catch (Exception ex) {
            ErrorLogHandler.createLog('CEE_OpportunityTriggerHandler.createOLIsFromOpportunity()', 'Apex Class', ex, String.join(listRecordReference, ', '), null, null);      
        }
    }
    
    public static void generateRollNumber(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppsMap) {
        
        Set<Id> productIdsToUpdate = new Set<Id>();
        List<Opportunity> oppsToProcess = new List<Opportunity>();
        
        try{
            
            for (Opportunity opp : newOpps) {
                Opportunity oldOpp = oldOppsMap != null ? oldOppsMap.get(opp.Id) : null;
                
                Boolean isNowApplicant = (opp.StageName == System.Label.Applicant_Stage);
                Boolean isNowStudent   = (opp.StageName == System.Label.Student_Stage);
                
                Boolean needsAppNumber = (isNowApplicant || isNowStudent) 
                    && String.isBlank(opp.Roll_Number__c);
                
                Boolean needsStudentNumber = isNowStudent 
                    && String.isBlank(opp.Student_Roll_Number__c);
                
                if ((needsAppNumber || needsStudentNumber) && opp.APP_Product__c != null) {
                    oppsToProcess.add(opp);
                    productIdsToUpdate.add(opp.APP_Product__c);
                }
            }
            
            if (productIdsToUpdate.isEmpty()) return;
            
            Map<Id, Product2> productMap = new Map<Id, Product2>([
                SELECT Id, Name, 
                Sequence_Counter__c,              
                Roll_Number_Counter__c, 
                Program_Short_Form__c, 
                Start_Date__c 
                FROM Product2 
                WHERE Id IN :productIdsToUpdate 
                FOR UPDATE
            ]);
            
            for (Opportunity opp : oppsToProcess) {
                Product2 prod = productMap.get(opp.APP_Product__c);
                
                if (prod != null) {
                    if (prod.Start_Date__c == null) {
                        opp.addError('Product "' + prod.Name + '" is missing a Programme Start Date.');
                        continue;
                    }
                    
                    String shortForm = String.isNotBlank(prod.Program_Short_Form__c) ? prod.Program_Short_Form__c : 'GEN';
                    
                    String yearShort = String.valueOf(prod.Start_Date__c.year()).substring(2, 4);
                    String month = String.valueOf(prod.Start_Date__c.month()).leftPad(2, '0');
                    String datePart = yearShort + month;
                    
                    if (String.isBlank(opp.Student_Roll_Number__c)) {
                        Decimal appCounter = (prod.Roll_Number_Counter__c == null) ? 0 : prod.Roll_Number_Counter__c;
                        appCounter++; 
                        prod.Roll_Number_Counter__c = appCounter; // Update Product Memory
                        
                        String appSeq = String.valueOf(Integer.valueOf(appCounter)).leftPad(3, '0');
                        
                        opp.Student_Roll_Number__c = 'ISB_' + shortForm + '_' + datePart + '_' + appSeq;
                    }
                    
                    if (String.isBlank(opp.Roll_Number__c)) {
                        Decimal rollCounter = (prod.Sequence_Counter__c == null) ? 0 : prod.Sequence_Counter__c;
                        rollCounter++; 
                        prod.Sequence_Counter__c = rollCounter;
                        
                        String rollSeq = String.valueOf(Integer.valueOf(rollCounter)).leftPad(3, '0');
                        
                        opp.Roll_Number__c = 'OP_' + shortForm + '_' + datePart + '_' + rollSeq;
                    }
                }
            }
            
            if (!productMap.isEmpty()) {
                List<Product_Counter_Update__e> eventsToPublish = new List<Product_Counter_Update__e>();
                
                for (Product2 prod : productMap.values()) {
                    Product_Counter_Update__e pe = new Product_Counter_Update__e();
                    pe.Product_Id__c = prod.Id;
                    pe.Roll_Number_Counter__c = prod.Roll_Number_Counter__c;
                    pe.Sequence_Counter__c = prod.Sequence_Counter__c;
                    eventsToPublish.add(pe);
                }
                
                if(!eventsToPublish.isEmpty()){
                    EventBus.publish(eventsToPublish);
                }
            }
            
        } catch (Exception ex) {
            ErrorLogHandler.createLog('CEE_OpportunityTriggerHandler.generateRollNumber()', 'Apex Class', ex, null, null, null);      
        }
        
    }
    
    
    public static void validatePriceBookChange(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        try{
            if (System.isBatch()) {
                return;
            }
            
            for (Opportunity opp : newOpps) {
                Opportunity oldOpp = oldOppMap.get(opp.Id);
                
                if (opp.Pricebook2Id != oldOpp.Pricebook2Id) {
                    if (oldOpp.StageName == System.Label.Stage_OfferOpen) {
                        opp.addError('The Price Book cannot be changed once the Opportunity has reached the "Offer Open" stage.');
                    }
                }
            }
            
        } catch (Exception ex) {
            ErrorLogHandler.createLog('CEE_OpportunityTriggerHandler.validatePriceBookChange()', 'Apex Class', ex, null, null, null);      
        }
        
    }
    
    
    
    public static void HROppStageChange(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        Set<Id> wonParentIds = new Set<Id>();
        List<Opportunity> oppWonList = new List<Opportunity>();
        List<Opportunity> oppLostList = new List<Opportunity>();
        List<String> listRecordReference = new List<String>();
        
        try{
            
            if(oldOppMap != null){
                
                for (Opportunity opp : newOpps) {
                    Opportunity oldOpp = oldOppMap.get(opp.Id);
                    listRecordReference.add(opp.Id);
                    if (opp.StageName != oldOpp.StageName) {
                        if (opp.StageName == System.Label.Closed_Won) {
                            oppWonList.add(opp);
                            wonParentIds.add(opp.Id);
                        }
                        else if(opp.StageName == System.Label.Closed_Lost){
                            oppLostList.add(opp);
                        }
                    }
                }
                
            }
            else{
                for (Opportunity opp : newOpps) {
                    Opportunity oldOpp = oldOppMap.get(opp.Id);
                    if (opp.StageName == System.Label.Closed_Won) {
                        oppWonList.add(opp);
                        wonParentIds.add(opp.Id);
                    }
                    else if(opp.StageName == System.Label.Closed_Lost){
                        oppLostList.add(opp);
                    }
                    
                }
            }
            
            System.debug('Opp won List:------------------------------' + oppWonList);
            
            if (!oppWonList.isEmpty()) {
                createB2BOLIs(wonParentIds);
                //propagateB2BDetails(newOpps, oldOppMap);
            }
            
            List<Opportunity> nomineeWonList = new List<Opportunity>();
            List<Opportunity> nomineeLostList = new List<Opportunity>();
            
            /* // THIS BLOCK IS REMOVED AS IT WAS CONFLICTING WITH propagateB2BDetails
            if(oppWonList.size() > 0 ){
                nomineeWonList = [ 
                    SELECT Id, Name, APP_Email__c, APP_MobilePhone__c, APP_First_Name__c, APP_Last_Name__c, StageName
                    FROM Opportunity 
                    WHERE Opportunity__c IN:oppWonList 
                ];
            }
       
        if(oppLostList.size() > 0 ){
           		nomineeLostList = [ 
                    SELECT Id, Name, APP_Email__c, APP_MobilePhone__c, APP_First_Name__c, APP_Last_Name__c, StageName
                	FROM Opportunity 
                	WHERE Opportunity__c IN:oppLostList 
 				];
       	}
       
            
            if(nomineeWonList.size() > 0 ){
                for(Opportunity nom : nomineeWonList){
                    nom.StageName = System.label.Student_Stage;
                }
                try {
                    // PERFORM UPDATE
                    update nomineeWonList;
                    
                    // --- CALL EMAIL METHOD HERE ---
                    // Only called if update succeeds
                    sendFinanceNotificationEmail(wonParentIds);
                    
                } catch (Exception e) {
                    System.debug('Error updating Nominees: ' + e.getMessage());
                }
                
            }
            */
            
            // Re-added this so the email still fires if needed, without the conflicting update logic above
            if(!wonParentIds.isEmpty()){
                 sendFinanceNotificationEmail(wonParentIds);
            }
            
            if(oppLostList.size() > 0 ){
                nomineeLostList = [ 
                    SELECT Id, Name, APP_Email__c, APP_MobilePhone__c, APP_First_Name__c, APP_Last_Name__c, StageName
                    FROM Opportunity 
                    WHERE Opportunity__c IN:oppLostList 
                ];
            }
            
            
            if(nomineeLostList.size() > 0 ){
                for(Opportunity nom : nomineeLostList){
                    nom.StageName = System.Label.Lost_Stage;
                }
                update nomineeLostList;
            }
            
            
        } catch (Exception ex) {
            ErrorLogHandler.createLog('CEE_OpportunityTriggerHandler.HROppStageChange()', 'Apex Class', ex, String.join(listRecordReference, ', '), null, null);      
        }
        
        
        
    }
    
    
    public static void sendFinanceNotificationEmail(Set<Id> parentIds) {
        if (parentIds.isEmpty()) return;
        
        
        // 1. Get Finance Group Member IDs
        Set<Id> userIds = new Set<Id>();
        List<String> listRecordReference = new List<String>();
        
        try{
            
            for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE Group.DeveloperName =: System.Label.Group_FinanceTeam]) {
                // Ensure the ID belongs to a User (Users start with '005')
                if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                    userIds.add(gm.UserOrGroupId);
                }
            }
            
            // 2. Query the User object for active emails
            List<String> toAddresses = new List<String>();
            if (!userIds.isEmpty()) {
                for (User u : [SELECT Email FROM User WHERE Id IN :userIds AND IsActive = true]) {
                    if (u.Email != null) toAddresses.add(u.Email);
                }
            }
            
            if (toAddresses.isEmpty()) return;
            
            // 2. Get the Email Template
            EmailTemplate et = [SELECT Id, Subject, HtmlValue, Body FROM EmailTemplate WHERE DeveloperName =: System.Label.B2BOfferActivatedFinance_Email LIMIT 1];
            
            // 3. Query Nominees and group them by Parent HR ID
            Map<Id, List<Opportunity>> parentToNomineesMap = new Map<Id, List<Opportunity>>();
            for (Opportunity nom : [SELECT Name, APP_Email__c, StageName, Opportunity__c FROM Opportunity WHERE Opportunity__c IN :parentIds]) {
                if (!parentToNomineesMap.containsKey(nom.Opportunity__c)) {
                    parentToNomineesMap.put(nom.Opportunity__c, new List<Opportunity>());
                }
                parentToNomineesMap.get(nom.Opportunity__c).add(nom);
            }
            
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            
            for (Id parentId : parentToNomineesMap.keySet()) {
                listRecordReference.add(parentId);
                List<Opportunity> childNominees = parentToNomineesMap.get(parentId);
                
                // 4. Build the HTML Table String
                String tableHtml = '<table border="1" style="border-collapse: collapse; width: 100%; font-family: sans-serif;">';
                tableHtml += '<tr style="background-color: #f2f2f2;"><th>Nominee Name</th><th>Email</th><th>Stage</th></tr>';
                for (Opportunity nom : childNominees) {
                    tableHtml += '<tr><td style="padding: 8px;">' + nom.Name + '</td>';
                    tableHtml += '<td style="padding: 8px;">' + (nom.APP_Email__c != null ? nom.APP_Email__c : 'N/A') + '</td>';
                    tableHtml += '<td style="padding: 8px;">' + nom.StageName + '</td></tr>';
                }
                tableHtml += '</table>';
                
                // 5. Use Messaging.renderStoredEmailTemplate to merge the Parent Info
                Messaging.SingleEmailMessage renderedMail = Messaging.renderStoredEmailTemplate(et.Id, UserInfo.getUserId(), parentId);
                
                String finalHtmlBody = renderedMail.getHtmlBody();
                // Replace the placeholder in the template with our dynamic table
                if (finalHtmlBody.contains('{{{NomineeTable}}}')) {
                    finalHtmlBody = finalHtmlBody.replace('{{{NomineeTable}}}', tableHtml);
                } else {
                    // Fallback if placeholder is missing
                    finalHtmlBody += '<br/>' + tableHtml;
                }
                
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

                // --- ADD CC ADDRESSES HERE (from Custom Label) ---
                String appSupportCc = Label.App_Support_Email;
                if (String.isNotBlank(appSupportCc)) {
                    mail.setCcAddresses(new List<String>{appSupportCc});
                }
                // --------------------------------------------------
                mail.setToAddresses(toAddresses);
                mail.setSubject(renderedMail.getSubject());
                mail.setHtmlBody(finalHtmlBody);
                emails.add(mail);
            }
            
            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails);
            }
            
        } catch (Exception ex) {
            ErrorLogHandler.createLog('CEE_OpportunityTriggerHandler.sendFinanceNotificationEmail()', 'Apex Class', ex, String.join(listRecordReference, ', '), null, null);      
        }
        
        
    }
    
    public static void LockEducationWorkexRecords(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        
        List<Id> contactIds = new List<Id>();
        Id contactId;
        List<String> listrecordReference = new List<String>();
        
        try{
            
            for(Opportunity opp : newOpps){
                
                Opportunity oldOpp = oldOppMap.get(opp.Id);
                listrecordReference.add(opp.Id);
                if(opp.StageName == System.Label.Applicant_Stage && opp.StageName != oldOppMap.get(opp.Id).StageName){
                    contactIds.add(opp.APP_Contact__c);
                }
                
            }
            
            List<Work_Ex__c> workExListToUpdate = new List<Work_Ex__c>();
            List<Education__c> educationListToUpdate = new List<Education__c>();    
            
            if(contactIds.size() > 0){
                
                List<Work_Ex__c> workExForContact = [SELECT Id, Is_Locked__c FROM Work_Ex__c WHERE Contact__c IN :contactIds];
                List<Education__c> educationForContact = [SELECT Id, Is_Locked__c FROM Education__c WHERE Contact__c IN :contactIds];
                
                if(workExForContact.isEmpty() || educationForContact.isEmpty()){
                    return;
                }
                
                if(!workExForContact.isEmpty()){
                    
                    for(Work_Ex__c workEx : workExForContact){
                        Work_Ex__c workExToUpdate = new Work_Ex__c();
                        if(workEx.Is_Locked__c == false){
                            workExToUpdate.Id = workEx.Id;
                            workExToUpdate.Is_Locked__c = true;
                            workExListToUpdate.add(workExToUpdate);
                        }
                        
                    }
                    
                }
                
                if(!educationForContact.isEmpty()){
                    
                    for(Education__c education : educationForContact){
                        Education__c educationToUpdate = new Education__c();
                        if(education.Is_Locked__c == false){
                            educationToUpdate.Id = education.Id;
                            educationToUpdate.Is_Locked__c = true;
                            educationListToUpdate.add(educationToUpdate);
                        }
                    }
                    
                }
                
                if(workExListToUpdate.size() > 0){
                    update workExListToUpdate;
                }
                
                
                if(educationListToUpdate.size() > 0){
                    update educationListToUpdate;
                }
                
                
            }
            
            
        } catch (Exception ex) {
            ErrorLogHandler.createLog('CEE_OpportunityTriggerHandler.LockEducationWorkexRecords()', 'Apex Class', ex, String.join(listRecordReference, ', '), null, null);      
        }
        
    }
    
    public static void validateB2BClosure(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        for (Opportunity opp : newOpps) {
            // Check if Stage is changing to 'Closed Won'
            if (opp.Record_Type_Name__c == 'CEE-HR' && (opp.StageName == 'Closed Won' && oldMap.get(opp.Id).StageName != 'Closed Won')) {
                
                if (String.isBlank(opp.APP_Citizeship__c)) {
                    opp.addError('Citizenship must be selected on the Parent Opportunity before closing.');
                }
                
                // Requirement: At least one of the following must be provided
                boolean hasPOParent = String.isNotBlank(opp.Parent_PO_Number__c);
                System.debug('The PO IS True:----------------------------------------' + hasPOParent);
                boolean hasPO = String.isNotBlank(opp.PO_Number__c);
                System.debug('The PO IS True:----------------------------------------' + hasPO);
                boolean hasUTR = String.isNotBlank(opp.UTR_Number__c);
                System.debug('The UTR IS True:----------------------------------------' + hasUTR);
                boolean hasSponsorship = (opp.Sponsorship_Details_Available__c == 'Yes');
                 System.debug('The Spons IS True:----------------------------------------' + hasSponsorship);
                
                if (!hasPO && !hasUTR && !hasSponsorship && !hasPOParent) {
                    opp.addError('MANDATORY: PO Number, UTR Number, or Company Sponsorship Letter (Yes) must be provided before identifying as Closed Won.');
                }
                
                 if (opp.Number_of_approved_nominee__c == null || opp.Number_of_approved_nominee__c <= 0) {
                    opp.addError('Atleast 1 Nominee is required to move the Stage to Closed Won');
                }
            }
        }
    }
    
    public static void propagateB2BDetails(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        Set<Id> closedWonIds = new Set<Id>();
        
        for (Opportunity opp : newOpps) {
            if (opp.StageName == 'Closed Won' && oldMap.get(opp.Id).StageName != 'Closed Won') {
                closedWonIds.add(opp.Id);
            }
        }
        
        if (!closedWonIds.isEmpty()) {
            // Check if we are already in an async context to avoid future-in-future errors
            if (System.isFuture() || System.isBatch() || System.isQueueable()) {
                updateChildB2BOpps(closedWonIds);
            } else {
                updateChildB2BOppsAsync(closedWonIds);
            }
        }
    }

    // Runs asynchronously so the Flow can safely generate the PDF/VF Email
    @future(callout=true)
    public static void updateChildB2BOppsAsync(Set<Id> closedWonIds) {
        updateChildB2BOpps(closedWonIds);
    }

    public static void updateChildB2BOpps(Set<Id> closedWonIds) {
        // Query parent fields since we only passed IDs to the future method
        Map<Id, Opportunity> parentMap = new Map<Id, Opportunity>([
            SELECT Id, PO_Number__c, UTR_Number__c, Sponsorship_Details_Available__c, APP_Citizeship__c,APP_CurrentIndustry__c, Sub_Industry__c
            FROM Opportunity 
            WHERE Id IN :closedWonIds
        ]);
        
            List<Opportunity> nomineesValues = [SELECT Id, Opportunity__c, StageName FROM Opportunity WHERE Opportunity__c IN :closedWonIds];
            List<Opportunity> toUpdate = new List<Opportunity>();
            
            for (Opportunity nom : nomineesValues) {
                Opportunity parent = parentMap.get(nom.Opportunity__c);
                if (parent != null) {
                    nom.PO_Number__c = parent.PO_Number__c;
                    nom.UTR_Number__c = parent.UTR_Number__c;
                    nom.Sponsorship_Details_Available__c = parent.Sponsorship_Details_Available__c;
                    nom.APP_Citizeship__c = parent.APP_Citizeship__c;
                nom.APP_CurrentIndustry__c = parent.APP_CurrentIndustry__c;
                nom.Sub_Industry__c = parent.Sub_Industry__c;
                    nom.StageName = 'Offer Open'; 
                    toUpdate.add(nom);
                }
            }
            
            if (!toUpdate.isEmpty()) {
                update toUpdate;
        }
    }
    
    public static void validateStudentConversion(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        validateInstallmentPaymentForStudent(newOpps, oldMap);
        validateB2BStudentConversion(newOpps, oldMap);
        validateB2C2BStudentConversion(newOpps, oldMap);
    }

    @TestVisible
    private static void validateInstallmentPaymentForStudent(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        Set<Id> oppIds = new Set<Id>();
        List<Opportunity> changingToStudent = new List<Opportunity>();
        //Added comment to restrict the bd to changes it to Student without payment
        //ISB-5833
        for (Opportunity opp : newOpps) {
            if (opp.StageName == 'Student' && oldMap.get(opp.Id).StageName != 'Student') {
                // Skip B2B/nominee child opps — their payments live on the parent opp, not the child.
                Boolean isChildNominee = (opp.Opportunity__c != null);
                Boolean isB2BOrSponsored = (opp.Opportunity_Type__c == 'B2B' || opp.APP_NominatedBy__c == 'Sponsored by Company');
                
                if (isChildNominee && isB2BOrSponsored) {
                    continue;
                }
                oppIds.add(opp.Id);
                changingToStudent.add(opp);
            }
        }

        if (changingToStudent.isEmpty()) return;

        // Collect Opp IDs that have at least one qualifying payment
        Set<Id> oppIdsWithPaidInstallment = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Opportunity__c oppId
            FROM EE_DL_Payment__c
            WHERE Opportunity__c IN :oppIds
              AND Payment_Type__c = 'Installment'
              AND Payment_status__c = 'Paid'
            GROUP BY Opportunity__c
        ]) {
            oppIdsWithPaidInstallment.add((Id) ar.get('oppId'));
        }

        for (Opportunity opp : changingToStudent) {
            if (!oppIdsWithPaidInstallment.contains(opp.Id)) {
                opp.addError('You cannot mark this Opportunity as Student without a confirmed installment payment. Please ensure a payment record with Payment Type = Installment and Payment Status = Paid exists.');
            }
        }
    }
    
    private static void validateB2BStudentConversion(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        Set<Id> parentIds = new Set<Id>();
        List<Opportunity> oppsToValidate = new List<Opportunity>();
        
        for (Opportunity opp : newOpps) {
            // Check for Stage Change to Student
            if (opp.StageName == 'Student' && oldMap.get(opp.Id).StageName != 'Student') {
                // Strict B2B Check: Opportunity_Type__c is 'B2B' OR RecordType implies B2B (Customise if needed)
                // Assuming 'B2B' type identifier based on previous context
                if (opp.Opportunity_Type__c == 'B2B') {
                    oppsToValidate.add(opp);
                    if (opp.Opportunity__c != null) {
                        parentIds.add(opp.Opportunity__c);
                    }
                }
            }
        }
        
        if (oppsToValidate.isEmpty()) return;
        
        validatePaymentDetails(oppsToValidate, parentIds);
    }
    
    private static void validateB2C2BStudentConversion(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        Set<Id> parentIds = new Set<Id>();
        List<Opportunity> oppsToValidate = new List<Opportunity>();
        
        for (Opportunity opp : newOpps) {
            // Check for Stage Change to Student
            if (opp.StageName == 'Student' && oldMap.get(opp.Id).StageName != 'Student') {
                
                // B2C2B Logic: Sponsored by Company but NOT pure B2B Type (implied)
                // AND Sub-Stage implies Company Payment
                if (opp.Opportunity_Type__c != 'B2B' && opp.APP_NominatedBy__c == 'Sponsored by Company' && (opp.Sub_Stage__c == 'Company Payment' || opp.Opportunity__c != null)) {
                    oppsToValidate.add(opp);
                    if (opp.Opportunity__c != null) {
                        parentIds.add(opp.Opportunity__c);
                    }
                }
            }
        }
        
        if (oppsToValidate.isEmpty()) return;
        
        validatePaymentDetails(oppsToValidate, parentIds);
    }
    
    private static void validatePaymentDetails(List<Opportunity> oppsToValidate, Set<Id> parentIds) {
        // Query Parent Details
        Map<Id, Opportunity> parentMap = new Map<Id, Opportunity>();
        if (!parentIds.isEmpty()) {
            parentMap = new Map<Id, Opportunity>([
                SELECT Id, PO_Number__c, UTR_Number__c, Sponsorship_Details_Available__c 
                FROM Opportunity 
                WHERE Id IN :parentIds
            ]);
        }
        
        for (Opportunity opp : oppsToValidate) {
            Opportunity parent = parentMap.get(opp.Opportunity__c);
            
            // Check Child Fields
            boolean childHasPO = String.isNotBlank(opp.PO_Number__c);
            boolean childHasUTR = String.isNotBlank(opp.UTR_Number__c);
            boolean childHasSponsorship = (opp.Sponsorship_Details_Available__c == 'Yes');
            
            // Check Parent Fields
            boolean parentHasPO = (parent != null && String.isNotBlank(parent.PO_Number__c));
            boolean parentHasUTR = (parent != null && String.isNotBlank(parent.UTR_Number__c));
            boolean parentHasSponsorship = (parent != null && parent.Sponsorship_Details_Available__c == 'Yes');
            
            // Pass if ANY field is present
            if (!childHasPO && !childHasUTR && !childHasSponsorship && !parentHasPO && !parentHasUTR && !parentHasSponsorship) {
                opp.addError('For Company Sponsored applications (Company Payment), PO Number, UTR Number, or Company Sponsorship Letter (Yes) must be provided.');
            }
        }
    }
    
    public static void validateNomineeConversion(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        Set<Id> parentIds = new Set<Id>();
        List<Opportunity> convertingOpps = new List<Opportunity>();
        
        for (Opportunity opp : newOpps) {
            // Check if moving to 'Student' - Handle null checks
            String newStage = opp.StageName;
            String oldStage = oldMap.get(opp.Id).StageName;
            
            if (newStage == 'Student' && oldStage != 'Student' && opp.Opportunity__c != null) {
                parentIds.add(opp.Opportunity__c);
                convertingOpps.add(opp);
            }
        }
        
        if (!parentIds.isEmpty()) {
            // Map<ParentId, AllowedLimit>
            Map<Id, Decimal> limitMap = new Map<Id, Decimal>();
            Map<Id, Integer> currentCountMap = new Map<Id, Integer>();
            
            // Fetch Limits
            for (Opportunity parent : [SELECT Id, Number_of_approved_nominee__c FROM Opportunity WHERE Id IN :parentIds]) {
                limitMap.put(parent.Id, parent.Number_of_approved_nominee__c != null ? parent.Number_of_approved_nominee__c : 0);
                currentCountMap.put(parent.Id, 0); // Init
            }
            
            // Count existing Students (excluding the ones currently being updated)
            for (AggregateResult ar : [SELECT Opportunity__c, COUNT(Id) cnt FROM Opportunity WHERE Opportunity__c IN :parentIds AND StageName = 'Student' GROUP BY Opportunity__c]) {
                currentCountMap.put((Id)ar.get('Opportunity__c'), (Integer)ar.get('cnt'));
            }
            
            for (Opportunity opp : convertingOpps) {
                Decimal allowed = limitMap.get(opp.Opportunity__c);
                Integer current = currentCountMap.get(opp.Opportunity__c);
                
                if (allowed != null && (current + 1) > allowed) {
                    opp.addError('Limit Reached: Only ' + allowed + ' nominees can be converted to Student. Currently ' + current + ' are approved.');
                } else {
                    // Increment for the next one in the batch
                    currentCountMap.put(opp.Opportunity__c, current + 1);
                }
            }
        }
    }
    
    public static void createB2BOLIs(Set<Id> oppIds) {
        if (oppIds == null || oppIds.isEmpty()) return;
        
        Set<Id> productIds = new Set<Id>();
        Set<Id> pricebookIds = new Set<Id>();
        List<Opportunity> oppsToProcess = new List<Opportunity>();
        
        // 1. Get Parent Opportunities
        Map<Id, Opportunity> parentOppMap = new Map<Id, Opportunity>([
            SELECT Id, APP_Product__c, Pricebook2Id, Number_of_approved_nominee__c,
            APP_HasSEZCertificate__c, APP_Citizeship__c 
            FROM Opportunity 
            WHERE Id IN :oppIds
        ]);
        
        for (Opportunity opp : parentOppMap.values()) {
            if (opp.APP_Product__c != null && opp.Pricebook2Id != null) {
                oppsToProcess.add(opp);
                productIds.add(opp.APP_Product__c);
                pricebookIds.add(opp.Pricebook2Id);
            }
        }
        
        if (oppsToProcess.isEmpty()) return;
        
        // 2. Query Pricebook Entries (Need UnitPrice for List Price calculation)
        Map<String, PricebookEntry> pbeMap = new Map<String, PricebookEntry>();
        List<PricebookEntry> pbes = [
            SELECT Id, Product2Id, Pricebook2Id, UnitPrice, IsActive, Total_Price_After_Discount__c, Discount_in_Percentage__c
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
            AND Pricebook2Id IN :pricebookIds
            AND IsActive = true
        ];
        
        for (PricebookEntry p : pbes) {
            pbeMap.put(String.valueOf(p.Pricebook2Id) + '|' + String.valueOf(p.Product2Id), p);
        }
        
        // 3. Query Product Details
        Map<Id, Product2> productMap = new Map<Id, Product2>([
            SELECT Id, GST_Applicable__c, GST__c, 
            Installment_Distribution__c, Installment_Due_Date_Structure__c, Start_Date__c 
            FROM Product2
            WHERE Id IN :productIds
        ]);
        
        // 4. Check for existing OLIs to avoid duplicates
        Set<Id> existingOliOppIds = new Set<Id>();
        for(OpportunityLineItem oli : [SELECT OpportunityId FROM OpportunityLineItem WHERE OpportunityId IN :oppsToProcess]){
            existingOliOppIds.add(oli.OpportunityId);
        }
        
        List<OpportunityLineItem> olisToInsert = new List<OpportunityLineItem>();
        
        for (Opportunity opp : oppsToProcess) {
            if(existingOliOppIds.contains(opp.Id)) continue;
            
            String pbeKey = String.valueOf(opp.Pricebook2Id) + '|' + String.valueOf(opp.APP_Product__c);
            
            if (pbeMap.containsKey(pbeKey)) {
                PricebookEntry pbe = pbeMap.get(pbeKey);
                Product2 prod = productMap.get(opp.APP_Product__c);
                
                // Sales Price Calculation (Per Unit)
                Decimal basePrice = pbe.Total_Price_After_Discount__c != null ? pbe.Total_Price_After_Discount__c : pbe.UnitPrice;

                Decimal gstRate = 0;
                
                if (prod != null && prod.GST_Applicable__c == true && prod.GST__c != null) {
                    Boolean isSez = (opp.APP_HasSEZCertificate__c == true);
                    Boolean isIndia = (opp.APP_Citizeship__c == 'India');
                    
                    if (!isSez && isIndia) {
                        gstRate = prod.GST__c;
                    }
                }
                Decimal gstAmount = basePrice * (gstRate / 100);
                
                // Determine Quantity (Nominees)
                Decimal manualQty = (opp.Number_of_approved_nominee__c != null && opp.Number_of_approved_nominee__c > 0) 
                    ? opp.Number_of_approved_nominee__c : 1;
                
                OpportunityLineItem oli = new OpportunityLineItem();
                oli.OpportunityId = opp.Id;
                oli.Product2Id = opp.APP_Product__c;
                oli.PricebookEntryId = pbe.Id;
                oli.Quantity = manualQty;
                oli.UnitPrice = basePrice + gstAmount; // Standard Salesforce OLI Price includes Tax/GST if applicable
                oli.Discount = pbe.Discount_in_Percentage__c;
                oli.Description = 'B2B Manual Nomination billing for ' + oli.Quantity + ' participants. (Incl. ' + gstRate + '% GST)';
                
                olisToInsert.add(oli);
            }
        }
        
        if (!olisToInsert.isEmpty()) {
            insert olisToInsert;
        //     System.debug('Inserted ' + olisToInsert.size() + ' B2B Line Items.');
            
        //     // -------------------------------------------------------------------------
        //     // B2B SCHEDULE CREATION WITH WATERFALL DISCOUNT LOGIC
        //     // -------------------------------------------------------------------------
        //     List<OpportunityLineItemSchedule> schedulesToInsert = new List<OpportunityLineItemSchedule>();
            
        //     for (OpportunityLineItem oli : olisToInsert) {
        //         Product2 prod = productMap.get(oli.Product2Id);
        //         Opportunity opp = parentOppMap.get(oli.OpportunityId);
            
        //         // Only create schedules if Product has a Distribution config
        //         if (prod != null && String.isNotBlank(prod.Installment_Distribution__c)) {
            
        //             String pbeKey = String.valueOf(opp.Pricebook2Id) + '|' + String.valueOf(prod.Id);
        //             PricebookEntry pbe = pbeMap.get(pbeKey); 
            
        //             // Parse Distribution & Dates
        //             String distRaw = prod.Installment_Distribution__c.removeStart('INST-');
        //             List<String> distParts = distRaw.split(';');
            
        //             List<String> dateParts = new List<String>();
        //             if(String.isNotBlank(prod.Installment_Due_Date_Structure__c)){
        //                 dateParts = prod.Installment_Due_Date_Structure__c.removeStart('D-').split(';');
        //             }
            
        //             // --- STEP A: Calculate Gross Installments based on LIST PRICE ---
        //             // We must calculate the "Gross" amount for the ENTIRE line (UnitListPrice * Quantity)
        //             Decimal unitListPrice = pbe.UnitPrice; 
        //             Decimal totalListPriceForLine = unitListPrice * oli.Quantity;
            
        //             List<Decimal> installmentAmounts = new List<Decimal>();
        //             for(String part : distParts) {
        //                 Decimal share = totalListPriceForLine * (Decimal.valueOf(part) / 100);
        //                 installmentAmounts.add(share);
        //             }
            
        //             // --- STEP B: Calculate Total Discount for the ENTIRE line ---
        //             Decimal discountPercent = (pbe.Discount_in_Percentage__c != null) ? pbe.Discount_in_Percentage__c : 0;
        //             Decimal totalDiscountAmtForLine = totalListPriceForLine * (discountPercent / 100);
            
        //             // --- STEP C: Waterfall Discount Logic (Subtract from last installments) ---
        //             Decimal remainingDiscount = totalDiscountAmtForLine;
            
        //             // Iterate backwards to subtract discount
        //             for(Integer i = installmentAmounts.size() - 1; i >= 0; i--) {
        //                 if(remainingDiscount <= 0) break;
            
        //                 if(installmentAmounts[i] >= remainingDiscount) {
        //                     // Installment absorbs the remaining discount
        //                     installmentAmounts[i] = installmentAmounts[i] - remainingDiscount;
        //                     remainingDiscount = 0;
        //                 } else {
        //                     // Discount is larger than this installment; zero it out and carry over remainder
        //                     remainingDiscount = remainingDiscount - installmentAmounts[i];
        //                     installmentAmounts[i] = 0;
        //                 }
        //             }
            
        //             // --- STEP D: Create Schedule Records ---
        //             Decimal gstNumberValue = (prod.GST_Applicable__c == true && prod.GST__c != null) ? prod.GST__c : 0;
            
        //             for (Integer i = 0; i < installmentAmounts.size(); i++) {
        //                 OpportunityLineItemSchedule sch = new OpportunityLineItemSchedule();
        //                 sch.OpportunityLineItemId = oli.Id;
        //                 sch.Installment_Number__c = i + 1;
        //                 sch.Type = System.Label.Type_Revenue; // e.g. 'Revenue'
            
        //                 // 1. Set Base Amount (Net Installment Amount calculated above)
        //                 Decimal scheduleBaseAmount = installmentAmounts[i];
        //                 sch.Base_Amount__c = scheduleBaseAmount;
            
        //                 // 2. Calculate GST
        //                 Decimal scheduleGstAmount = scheduleBaseAmount * (gstNumberValue / 100);
        //                 sch.GST__c = gstNumberValue;
            
        //                 // 3. Set Total Revenue
        //                 sch.Revenue = scheduleBaseAmount + scheduleGstAmount;
            
        //                 // 4. Payment Status (Auto-paid if 0)
        //                 if(sch.Revenue <= 0) {
        //                     sch.Payment_Status__c = 'Paid';
        //                 } else {
        //                     sch.Payment_Status__c = System.Label.Status_NotPaid;
        //                 }
            
        //                 // 5. Date Logic
        //                 if (i == 0) {
        //                     if (prod.Start_Date__c != null) {
        //                         sch.ScheduleDate = prod.Start_Date__c.addDays(-1);
        //                     } else {
        //                         sch.ScheduleDate = System.today().addDays(1);
        //                     }
        //                 } else {
        //                     Integer dateIndex = i - 1;
        //                     if (dateIndex < dateParts.size()) {
        //                         Integer dayOffset = Integer.valueOf(dateParts[dateIndex]);
        //                         if (prod.Start_Date__c != null) {
        //                             sch.ScheduleDate = prod.Start_Date__c.addDays(dayOffset);
        //                         } else {
        //                             sch.ScheduleDate = System.today().addDays(dayOffset);
        //                         }
        //                     } else {
        //                         sch.ScheduleDate = System.today().addDays(30 * i);
        //                     }
        //                 }
            
        //                 schedulesToInsert.add(sch);
        //             }
        //         }
        //     }
            
        //     if(!schedulesToInsert.isEmpty()){
        //         insert schedulesToInsert;
        //         System.debug('B2B Schedules created: ' + schedulesToInsert.size());
        //     }
        }
    }
    
    public static void validateCitizenship(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        for (Opportunity opp : newOpps) {
            if (opp.StageName == 'Offer Open' && oldMap.get(opp.Id).StageName != 'Offer Open') {
                //if (String.isBlank(opp.APP_CurrentIndustry__c)) {
                  //  opp.addError('Current Industry is required before moving to Offer Open stage.');
                //}
                if (String.isBlank(opp.APP_Citizeship__c)) {
                    opp.addError('Citizenship is required before moving to Offer Open stage.');
                }
            }
        }
    }

    public static void determineGSTApplicability(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        for (Opportunity opp : newOpps) {
            // Check if this is an Insert OR if relevant fields changed during Update
            Boolean isInsert = (oldOppMap == null);
            Boolean isRelevantChange = false;
            
            if (!isInsert) {
                Opportunity oldOpp = oldOppMap.get(opp.Id);
                if (opp.APP_HasSEZCertificate__c != oldOpp.APP_HasSEZCertificate__c || opp.APP_Citizeship__c != oldOpp.APP_Citizeship__c) {
                    isRelevantChange = true;
                }
            }

            if (isInsert || isRelevantChange) {
                // AC1: If SEZ is TRUE -> GST NOT Applicable (Overrides everything)
                if (opp.APP_HasSEZCertificate__c == true) {
                    opp.GST_Applicable__c = false;
                }
                // AC2: If SEZ False AND Citizenship is India -> GST Applicable
                else if (opp.APP_Citizeship__c == 'India') {
                    opp.GST_Applicable__c = true;
                }
                // AC3: If SEZ False AND Citizenship is NOT India -> GST NOT Applicable
                else {
                    opp.GST_Applicable__c = false;
                }
            }
        }
    }

     public static void applyEarlyBirdPricebook(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        Set<Id> productIds = new Set<Id>();
        List<Opportunity> candidates = new List<Opportunity>();

        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldMap.get(opp.Id);

            if (opp.StageName == 'Applicant' && oldOpp.StageName != 'Applicant' && opp.APP_Product__c != null) {
                candidates.add(opp);
                productIds.add(opp.APP_Product__c);
            }
        }

        if (candidates.isEmpty()) return;

        Map<Id, Product2> productMap = new Map<Id, Product2>(
            [SELECT Id, Early_Bird_Start_Date__c, Early_Bird_End_Date__c 
             FROM Product2 
             WHERE Id IN :productIds]
        );

        List<Pricebook2> ebList = [SELECT Id FROM Pricebook2 WHERE Name = 'Earlybird Price Book' AND IsActive = true LIMIT 1];
        
        if (ebList.isEmpty()) {
            return; 
        }
        
        Id earlyBirdPbId = ebList[0].Id;
        Date todayDate = Date.today();

        for (Opportunity opp : candidates) {
            Product2 prod = productMap.get(opp.APP_Product__c);

            if (prod != null && prod.Early_Bird_Start_Date__c != null && prod.Early_Bird_End_Date__c != null) {
                if (todayDate >= prod.Early_Bird_Start_Date__c && todayDate <= prod.Early_Bird_End_Date__c) {
                    opp.Pricebook2Id = earlyBirdPbId;
                }
            }
        }
    }

    //LXP 2.0 - Student Creation and Enrolment
    public static void LMSCalloutForStudentStage(List<Opportunity> oppsUpdateList, Map<Id, Opportunity> oldOppMap) {         
        Set<Id> oppIdSetForLMS = new Set<Id>();
        List<String> listRecordReference = new List<String>();
        try{
            Id onlineProgOppRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Online Program').getRecordTypeId();
            String lostStage = System.Label.CLCEE00031;
            for (Opportunity opp : oppsUpdateList) {
                if(opp.RecordTypeId == onlineProgOppRecordType){
                    listRecordReference.add(opp.Id);
                    Opportunity oldOpp = oldOppMap != null ? oldOppMap.get(opp.Id) : null;

                    if(oldOpp != null && oldOpp.StageName != opp.StageName && oldOpp.StageName != lostStage && opp.StageName == System.Label.Student_Stage && 
                       (opp.LMS_Sync__c == false || opp.LMS_Access_Status__c == null || opp.LMS_Access_Status__c != 'Granted')){                  
                        oppIdSetForLMS.add(opp.Id);
                    }
                }
            }
            
            if(!oppIdSetForLMS.isEmpty()){
                System.enqueueJob(new LMSStudentCreationAndEnrolment(oppIdSetForLMS));
            }

        } catch (Exception ex) { ErrorLogHandler.createLog('CEE_OpportunityTriggerHandler.LMSCalloutForStudentStage()', 'Apex Class', ex, String.join(listRecordReference, ', '), null, null);}     
    }

    //LXP 2.0 - Revoke Access for Lost Opportunities
    public static void unenrolUsersForLostOpportunities(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        Set<Id> targetIds = new Set<Id>();
        Id onlineProgOppRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Online Program').getRecordTypeId();
        String lostStage = System.Label.CLCEE00031;
        String deferredSubStage = System.Label.CLCEE00032;
        String withdrewSubStage = System.Label.CLCEE00033;

        for (Opportunity opp : newOpps) {
            if(opp.RecordTypeId == onlineProgOppRecordType) {
                Opportunity oldOpp = oldMap != null ? oldMap.get(opp.Id) : null;
                if (oldOpp != null) {
                    Boolean stageChangedToLost = oldOpp.StageName != opp.StageName && opp.StageName == lostStage;
                    Boolean subStageChanged = oldOpp.Sub_Stage__c != opp.Sub_Stage__c;
                    Boolean isTargetSubstage = (opp.Sub_Stage__c == deferredSubStage || opp.Sub_Stage__c == withdrewSubStage);
                    if (opp.StageName == lostStage && isTargetSubstage && (stageChangedToLost || subStageChanged)) {
                        targetIds.add(opp.Id);
                    }
                }
            }
        }

        if (!targetIds.isEmpty()) {
            System.enqueueJob(
                new LXP_UnenrolQueueable(new List<Id>(targetIds))
            );
        }

    }



    //LXP 1.0 Integration callout EE DL - Added by Anitha for ISB-4808
    public static void LXPCalloutForStudentStage(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {         
        Set<Id> oppIdSetForLXP = new Set<Id>();
        List<String> listRecordReference = new List<String>();
        try{
            Id onlineProgOppRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Online Program').getRecordTypeId();
            for (Opportunity opp : newOpps) {
                listRecordReference.add(opp.Id);
                Opportunity oldOpp = oldOppMap.get(opp.Id);

                if(opp.RecordTypeId == onlineProgOppRecordType && oldOpp.StageName != opp.StageName && opp.StageName == System.Label.Student_Stage && opp.RecordTypeId == onlineProgOppRecordType && opp.LXP_Sync__c == false){                  
                    oppIdSetForLXP.add(opp.Id); 
                }
            }
            EE_DL_LXPCallout.sendEnrollmentCallouts(oppIdSetForLXP);   
        } catch (Exception ex) { ErrorLogHandler.createLog('CEE_OpportunityTriggerHandler.LXPCalloutForStudentStage()', 'Apex Class', ex, String.join(listRecordReference, ', '), null, null);}     
    }

    public static void revokeLXPAccessForLostOpportunities(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        Set<Id> targetIds = new Set<Id>();
        List<String> listRecordReference = new List<String>();
        try{
            Id onlineProgOppRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Online Program').getRecordTypeId();
            String lostStage = System.Label.CLCEE00031;
            String deferredSubStage = System.Label.CLCEE00032;
            String withdrewSubStage = System.Label.CLCEE00033;
            for (Opportunity opp : newOpps) {
                Opportunity oldOpp = oldMap != null ? oldMap.get(opp.Id) : null;
                if (oldOpp != null) {
                    listRecordReference.add(opp.Id);
                    Boolean stageChangedToLost = oldOpp.StageName != opp.StageName && opp.StageName == lostStage;
                    Boolean subStageChanged = oldOpp.Sub_Stage__c != opp.Sub_Stage__c;
                    Boolean isTargetSubstage = (opp.Sub_Stage__c == deferredSubStage || opp.Sub_Stage__c == withdrewSubStage);
                    if (opp.RecordTypeId == onlineProgOppRecordType && opp.StageName == lostStage && isTargetSubstage && (stageChangedToLost || subStageChanged)) {
                        targetIds.add(opp.Id);
                    }
                }
            }
            if (!targetIds.isEmpty()) {
                Database.executeBatch(new EE_DL_LXP_RevokeAccessBatch(targetIds, true), 50);
            }
        } catch (Exception ex) { ErrorLogHandler.createLog('CEE_OpportunityTriggerHandler.revokeAccessForLostOpportunities()', 'Apex Class', ex, String.join(listRecordReference, ', '), null, null);}     
        
    }

    
    public static void handleAccessRevoked(List<Opportunity> newList, Map<Id, Opportunity> oldMap){

        System.debug('=== handleAccessRevoked START ===');

        if(newList == null || newList.isEmpty()){
            return;
        }

        Set<Id> oppIds = new Set<Id>();
        List<String> listRecordReference = new List<String>();
        try{

            for(Opportunity opp : newList){

                Opportunity oldOpp = oldMap.get(opp.Id);

                if(oldOpp == null){
                    continue;
                }
                
                listRecordReference.add(opp.Id);

                System.debug('Checking Opp: ' + opp.Id);
                System.debug('OLD Status: ' + oldOpp.LXP_Access_Status__c);
                System.debug('NEW Status: ' + opp.LXP_Access_Status__c);
                System.debug('SYNC Flag: ' + opp.LXP_Sync__c);

                //  Main condition
                if(
                    opp.LXP_Access_Status__c == 'Revoked' &&
                    opp.LXP_Sync__c == true &&
                    oldOpp.LXP_Access_Status__c != 'Revoked'
                ){
                    System.debug(' Access Block Triggered for Opp: ' + opp.Id);
                    oppIds.add(opp.Id);
                }
            }

            System.debug('OppIds to process: ' + oppIds);

            if(!oppIds.isEmpty()){
                try{
                    sendAccessBlockedEmail(oppIds);
                    System.debug(' Future method invoked for OppIds: ' + oppIds);
                }catch(Exception e){
                    ErrorLogHandler.createLog(
                        'handleAccessRevoked - future call',
                        'Apex Class',
                        e,
                        String.join(listRecordReference, ', '),
                        null,
                        null
                    );
                }
            }
        }catch(Exception ex){
        ErrorLogHandler.createLog(
            'handleAccessRevoked',
            'Apex Class',
            ex,
            String.join(listRecordReference, ', '),
            null,
            null
            );
        }
    }

    // Access Blocked for LMS
    private static void sendAccessBlockedEmailInternal(List<Opportunity> oppList){
        System.debug('sendAccessBlockedEmailInternal1');
        if(oppList == null || oppList.isEmpty()){
            return;
        }

        List<String> listRecordReference = new List<String>();

        Set<Id> oppIds = new Set<Id>();
        try{
            for(Opportunity opp : oppList){
                oppIds.add(opp.Id);
                listRecordReference.add(opp.Id);
            }

            /* -------------------------------------------------
            STEP 1 — Get Email Template
            --------------------------------------------------- */
            System.debug('sendAccessBlockedEmailInternal2');
            List<EmailTemplate> templates = [
                SELECT Id
                FROM EmailTemplate
                WHERE DeveloperName = 'Access_Blocked_In_Programme'
                LIMIT 1
            ];

            if(templates.isEmpty()){
                return;
            }

            Id templateId = templates[0].Id;

            /* -------------------------------------------------
            STEP 2 — Get OrgWideEmailAddress
            --------------------------------------------------- */
            System.debug('sendAccessBlockedEmailInternal3');
            List<OrgWideEmailAddress> oweaList = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE Address = 'execed@isb.edu'
                LIMIT 1
            ];

            if(oweaList.isEmpty()){
                return;
            }

            Id orgWideEmailId = oweaList[0].Id;

            /* -------------------------------------------------
            STEP 3 — Fetch Unpaid Schedules (Overdue First)
            --------------------------------------------------- */

            List<OpportunityLineItemSchedule> schedules = [
                SELECT Id,
                    ScheduleDate,
                    OpportunityLineItemId,
                    Revenue,
                    Installment_Number__c,
                    Payment_Status__c,
                    Payment_Link__c,
                    Payment_Link_Id__c,
                    Payment_Link_Expire__c,
                    OpportunityLineItem.Id,
                    OpportunityLineItem.UnitPrice,
                    OpportunityLineItem.CEE_Name__c,
                    OpportunityLineItem.Product2Id,
                    OpportunityLineItem.Product2.Name,
                    OpportunityLineItem.Product2.Start_Date__c,
                    OpportunityLineItem.Product2.EndDate__c,
                    OpportunityLineItem.OpportunityId,
                    OpportunityLineItem.Opportunity.Id,
                    OpportunityLineItem.Opportunity.Name,
                    OpportunityLineItem.Opportunity.APP_MobilePhone__c,
                    OpportunityLineItem.Opportunity.APP_Contact__c,
                    OpportunityLineItem.Opportunity.APP_Contact__r.Name,
                    OpportunityLineItem.Opportunity.APP_Contact__r.Email,
                    OpportunityLineItem.Opportunity.APP_Contact__r.MobilePhone
                FROM OpportunityLineItemSchedule
                WHERE OpportunityLineItem.OpportunityId IN :oppIds
                AND Payment_Status__c = 'Not Paid'
                AND ScheduleDate <= TODAY
                ORDER BY ScheduleDate ASC
            ];

            System.debug('schedules inside send access revoked'+schedules);
            if(schedules.isEmpty()){
                return;
            }

            /* -------------------------------------------------
            STEP 4 — Map Schedule per Opportunity
            --------------------------------------------------- */

            Map<Id, OpportunityLineItemSchedule> oppToScheduleMap = new Map<Id, OpportunityLineItemSchedule>();

            for(OpportunityLineItemSchedule sch : schedules){

                Id oppId = sch.OpportunityLineItem.OpportunityId;

                if(!oppToScheduleMap.containsKey(oppId)){
                    oppToScheduleMap.put(oppId, sch);
                }
            }

            /* -------------------------------------------------
            STEP 5 — Generate Payment Links if Needed
            --------------------------------------------------- */

            List<OpportunityLineItemSchedule> schedulesToUpdate = new List<OpportunityLineItemSchedule>();

            for(OpportunityLineItemSchedule sch : oppToScheduleMap.values()){
                try{

                    if(
                        String.isBlank(sch.Payment_Link__c) ||
                        (sch.Payment_Link_Expire__c != null && sch.Payment_Link_Expire__c < System.now())
                    ){
                        EE_DL_RazorPayPaymentConnection.LinkResult lr =
                            EE_DL_RazorPayPaymentConnection.generateLinkData(sch, null);

                        if(lr != null){
                            sch.Payment_Link__c  = lr.shortUrl;
                            sch.Payment_Link_Id__c = lr.linkId;
                            sch.Payment_Link_Expire__c = lr.expiry;

                            schedulesToUpdate.add(sch);
                        }
                    }
                }catch(Exception innerEx){
                        ErrorLogHandler.createLog(
                            'sendAccessBlockedEmailInternal - payment link generation',
                            'Apex Class',
                            innerEx,
                            sch.Id,
                            null,
                            null
                        );
                    }
                }
                System.debug(schedulesToUpdate);

                if(!schedulesToUpdate.isEmpty()){
                    update schedulesToUpdate;
                }

            /* -------------------------------------------------
            STEP 6 — Send Emails
            --------------------------------------------------- */

            List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

            // Define the CC list outside the loop for efficiency (from Custom Label)
            String appSupportCc = Label.App_Support_Email;
            List<String> ccAddresses = new List<String>();
            if (String.isNotBlank(appSupportCc)) {
                ccAddresses.add(appSupportCc);
            }

            for(Opportunity opp : oppList){
                try{

                    if(opp.APP_Contact__c == null){
                        continue;
                    }

                    OpportunityLineItemSchedule sch = oppToScheduleMap.get(opp.Id);

                    if(sch == null){
                        continue;
                    }

                    Messaging.SingleEmailMessage mail =
                        Messaging.renderStoredEmailTemplate(
                            templateId,
                            opp.APP_Contact__c,
                            sch.Id
                        );

                    mail.setWhatId(opp.Id);
                    mail.setOrgWideEmailAddressId(orgWideEmailId);
                    mail.setSaveAsActivity(true);

                    // --- ADD THIS LINE TO SET THE CC ---
                    mail.setCcAddresses(ccAddresses); 
                    // ----

                    System.debug('Prepared email for Opp: ' + opp.Id + ' to Contact: ' + opp.APP_Contact__c);

                    emailList.add(mail);
                }catch(Exception innerEx){
                    ErrorLogHandler.createLog(
                        'sendAccessBlockedEmailInternal - email loop',
                        'Apex Class',
                        innerEx,
                        opp.Id,
                        null,
                        null
                    );
                }
            }

            if(!emailList.isEmpty()){
                Messaging.sendEmail(emailList);
            }
        }catch(Exception ex){
            ErrorLogHandler.createLog(
                'sendAccessBlockedEmailInternal',
                'Apex Class',
                ex,
                String.join(listRecordReference, ', '),
                null,
                null
            );
        }
    }

    @future(callout=true)
    public static void sendAccessBlockedEmail(Set<Id> oppIds){
        System.debug('sendAccessBlockedEmail called with Opp IDs: ' + oppIds);

        if(oppIds == null || oppIds.isEmpty()){
            return;
        }
        List<String> listRecordReference = new List<String>();

        try{

            for(Id oppId : oppIds){
                listRecordReference.add(String.valueOf(oppId));
            }            
            List<Opportunity> oppList = [
                SELECT Id, APP_Contact__c
                FROM Opportunity
                WHERE Id IN :oppIds
            ];

            sendAccessBlockedEmailInternal(oppList);
            System.debug('sendAccessBlockedEmail completed for Opp IDs: ' + oppIds);
        }catch(Exception ex){
            ErrorLogHandler.createLog(
                'sendAccessBlockedEmail',
                'Apex Class',
                ex,
                String.join(listRecordReference, ', '),
                null,
                null
            );
        }
    }

    private static Set<Id> getEEDLEligibleOpportunityRecordTypeIds() {
        Set<Id> eligibleRecordTypeIds = new Set<Id>();
        Map<String, Schema.RecordTypeInfo> recordTypesByDeveloperName =
            Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();

        for (String recordTypeDeveloperName : new Set<String>{
            'CEE_Custom',
            'CEE_HR',
            'CEE_Open_LDP',
            'CEE_Open_SDP',
            'EE_Govt',
            'ExecEd_B2B',
            'ExecEdDefault',
            'Online_Program'
        }) {
            if (recordTypesByDeveloperName.containsKey(recordTypeDeveloperName)) {
                eligibleRecordTypeIds.add(recordTypesByDeveloperName.get(recordTypeDeveloperName).getRecordTypeId());
            }
        }
        return eligibleRecordTypeIds;
    }

    public static void triggerEEDLVerification(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        Set<Id> oppIds = new Set<Id>();
        Set<Id> eligibleRecordTypeIds = getEEDLEligibleOpportunityRecordTypeIds();
        for (Opportunity opp : newList) {
            if (
                opp.StageName == 'Applicant'
                && oldMap.get(opp.Id).StageName != 'Applicant'
                && eligibleRecordTypeIds.contains(opp.RecordTypeId)
            ) {
                oppIds.add(opp.Id);
            }
        }
        if (oppIds.isEmpty()) return;
        try {
            AI_Server_ChokePoint__mdt chokePoint = [
                SELECT Is_Enabled__c FROM AI_Server_ChokePoint__mdt
                WHERE DeveloperName = 'EEDL_Automated_Verification' LIMIT 1
            ];
            if (chokePoint != null && chokePoint.Is_Enabled__c) {
                EEDLVerificationGateway.processOpportunities(oppIds);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'triggerEEDLVerification: ' + e.getMessage());
        }
    }
}
