/**
 * @description       : 
 * @author            : Anshul Verma
 * @group             : 
 * @last modified on  : 02-06-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
trigger CEE_OpportunityTrigger on Opportunity (before update,after insert,after update,before insert) {
    
    
    Map<String,Opportunity__c> mapTriggerCheck = Opportunity__c.getAll();
    System.debug('Inside CEE_OpportunityTrigger before customsettings check');
    System.debug(mapTriggerCheck+'mapTriggerCheck');
    if(mapTriggerCheck.get('Active').Activate_Trigger__c == true){
        System.debug('Inside CEE_OpportunityTrigger after customsettings check');
        if(trigger.isAfter && trigger.isInsert){
            CEE_OpportunityTriggerHandler.insertOpportunityId(Trigger.New);
            //CEE_OpportunityTriggerHandler.createInvoicesforOpportunity(Trigger.new);
            Map<Id,Opportunity> map_DeferralOppsForOLI = new Map<Id,Opportunity>();//added here 05-01 AV
            Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
            // CEE_OpportunityTriggerHandler.assingOwnerIdthroughRoundRobin(Trigger.new);
            // for(String OppId : trigger.oldMap.keyset()){
            Boolean needsPaxUpdate = false;
            for(opportunity OppId : Trigger.new){
                if(OppId.APP_Contact__c != Null) {
                    needsPaxUpdate = true;
                }
                if(OppId.Deferred_Opportunity__c != null){
                    map_DeferralOppsForOLI.put(OppId.Id, OppId);
                }//added here 05-01 AV
            }
            if(needsPaxUpdate) {
                CEE_OpportunityTriggerHandler.paxFieldUpdate(Trigger.new);
            }
            
            if(map_DeferralOppsForOLI.size() > 0){
                try{
                    CEE_OpportunityTriggerHandler.createOLIsFromOpportunity(map_DeferralOppsForOLI);
                } catch(Exception e){
                    System.debug('Error creating OLIs for Deferral Opp: ' + e.getMessage());
                }
            }
            
            
            for(String strCurOppId : trigger.newMap.keyset()){
                
                String strNewStageName =  trigger.newMap.get(strCurOppId).StageName;
                String deferredOppId = trigger.newMap.get(strCurOppId).Deferred_Opportunity__c;
                
                if((strNewStageName == 'Offer Accepted' || strNewStageName == 'Payment' || strNewStageName == 'Offer Open') && deferredOppId != null){
                    map_NewOpportuntiesById.put(strCurOppId,trigger.newMap.get(strCurOppId));
                }
            }
            if(map_NewOpportuntiesById.keyset().size()>0){
                DeferralQueueableClass dqc = new DeferralQueueableClass(map_NewOpportuntiesById);
                System.enqueueJob(dqc);
            }
            
        }
        if(trigger.isBefore && trigger.isInsert){

            CEE_OpportunityTriggerHandler.updateProductCode(Trigger.new);
            CEE_OpportunityTriggerHandler.updateProgrammeManager(Trigger.New);
            // OpportunityTriggerHandleGrants.handleBeforeInsert(Trigger.new);
            Id HRRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
            Id LDPRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
            Id SDPRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-SDP').getRecordTypeId();
            List<Opportunity> oppList = new List<Opportunity>();
            List<Opportunity> hrOppList = new List<Opportunity>();
            
            for(Opportunity opp : trigger.new){
                if(opp.Sub_Stage__c != null && opp.Lost_Sub_Status__c != null){
                    opp.Current_Status__c = opp.StageName + '-' + opp.Sub_Stage__c + '-' + opp.Lost_Sub_Status__c;
                }
                else if(opp.Sub_Stage__c != null){
                    opp.Current_Status__c = opp.StageName + '-' + opp.Sub_Stage__c;
                }
                else{
                    opp.Current_Status__c = opp.StageName;
                }
                opp.BD_Owner_Email__c = opp.Selected_Program_BD_Owner_Email__c;
                if(opp.RecordTypeId == HRRecordType || opp.RecordTypeId == LDPRecordType || opp.RecordTypeId == SDPRecordType){
                    system.debug('inside');
                    oppList.add(Opp);
                }
                                
            }
            if(oppList.size() > 0)
                CEE_OpportunityTriggerHandler.updateLeadSource(oppList);
            
        }
        if(trigger.isUpdate && trigger.isAfter){
            system.debug('After Update');
            CEE_OpportunityTriggerHandler.handleAccessRevoked(Trigger.new, Trigger.oldMap);
            CEE_OpportunityTriggerHandler.propagateB2BDetails(Trigger.new, Trigger.oldMap);
            Map<Id,Opportunity>  map_AppliedToOfferOpen = new Map<Id,Opportunity>();
            Map<Id,Opportunity>  map_NomineeOpportunties = new Map<Id,Opportunity>();
            Map<Id, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Opportunity.getRecordTypeInfosById();
            Id HRRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
            Id sdpOppRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-SDP').getRecordTypeId();
            Id ldpOppRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-Open-LDP').getRecordTypeId();
            Id onlineProgOppRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Online Program').getRecordTypeId();

            for(String strCurOppId : trigger.oldMap.keyset()){
                    String strOldStageName = trigger.oldMap.get(strCurOppId).StageName;
                    String strNewStageName =  trigger.newMap.get(strCurOppId).StageName;
                     String recordTypeName = rtMap.get(trigger.newMap.get(strCurOppId).RecordTypeId).getName();
                    //added for Applied to Offer Open stage change as per new EE/DL 'Applicant'
                    if(strOldStageName != System.Label.CLCEE00007 && strNewStageName == System.Label.CLCEE00007 
                    && (recordTypeName == System.Label.Online_Program_Record || recordTypeName == System.Label.CLCEE00008
                    || recordTypeName == System.Label.CLCEE00018 || recordTypeName == System.Label.CLCEE00024 )){
                        map_AppliedToOfferOpen.put(strCurOppId, trigger.newMap.get(strCurOppId));
                    }  
                    if(strOldStageName != System.Label.Opportunity_Student_Stage && strNewStageName == System.Label.Opportunity_Student_Stage && trigger.newMap.get(strCurOppId).Opportunity__c != null 
                    && (recordTypeName == System.Label.Online_Program_Record || recordTypeName == System.Label.CLCEE00008
                    || recordTypeName == System.Label.CLCEE00018 || recordTypeName == System.Label.CLCEE00024 )){
                        map_NomineeOpportunties.put(strCurOppId, trigger.newMap.get(strCurOppId));
                    }  
            }      
            // After collecting, create OLIs from EE_DL_ProgramInstallment__c for the set that moved Applied->Offer Open
                if(map_AppliedToOfferOpen.size() > 0){
                    try {
                        //CEE_OpportunityTriggerHandler.createOLIsFromInstallments(map_AppliedToOfferOpen);
                        // Call the new method to create OLI when stage changes to 'Offer Open'
                        CEE_OpportunityTriggerHandler.createOLIsFromOpportunity(map_AppliedToOfferOpen);

                        //Send an Email To Candidate On Offer Open Stage
                    System.enqueueJob(
                                new SendOfferLetterQueueable(map_AppliedToOfferOpen.keySet())
                            );
                    } catch(Exception e){
                        // log but do not stop trigger processing
                        System.debug('Error creating OLIs from installments: ' + e.getMessage());
                    }
                }
                // After collecting, create OLIs for nominees moving to 'Student' stage
                if(map_NomineeOpportunties.size() > 0){
                    try {
                        CEE_OpportunityTriggerHandler.createOLIsFromOpportunity(map_NomineeOpportunties);
                    } catch(Exception e){
                        // log but do not stop trigger processing
                        System.debug('Error creating Participant Info for nominees: ' + e.getMessage());
                    }
                }

                
            if(CEE_OpportunityTriggerHandler.flag && !CEE_OpportunityTriggerHandler.isInsertingOpportunityId){
                CEE_OpportunityTriggerHandler.flag = false;
                
                Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
                Map<Id,Opportunity>  map_OpportuntiesById = new Map<Id,Opportunity>();
                set<Id> oppIdSet = new set<Id>();
                List<Id> lostOpportunity = new List<Id>();
                for(String strCurOppId : trigger.oldMap.keyset()){
                    String strOldStageName = trigger.oldMap.get(strCurOppId).StageName;
                    String strNewStageName =  trigger.newMap.get(strCurOppId).StageName;
                    System.debug('74>>>'+strOldStageName);
                    System.debug('75>>>'+strNewStageName);
                    String strOpportunityName =  trigger.newMap.get(strCurOppId).Name;
                    String AccountId =  trigger.newMap.get(strCurOppId).AccountId;
                    String syncquote = trigger.newMap.get(strCurOppId).SyncedQuoteId;
                    
                    
                    if(strOldStageName != strNewStageName && (strNewStageName == System.Label.CLCEE00007)){
                        map_NewOpportuntiesById.put(strCurOppId,trigger.newMap.get(strCurOppId));
                        oppIdSet.add(strCurOppId);
                    }
                    if(strOldStageName != strNewStageName && (strNewStageName == System.Label.CLCEE00016 && strOldStageName == System.Label.CLCEE00015)){
                        map_OpportuntiesById.put(strCurOppId,trigger.newMap.get(strCurOppId));
                    }
                    if(strOldStageName != strNewStageName && strNewStageName == 'Lost' && trigger.newMap.get(strCurOppId).CloneOpportunity__c != null){
                        lostOpportunity.add(strCurOppId);
                    }
                    /*if(strOldStageName != strNewStageName && strNewStageName == 'Applied' && trigger.newMap.get(strCurOppId).Program_Application_Fee__c > 0 && trigger.newMap.get(strCurOppId).APP_ApplicationFeePaymentLink__c == null){
                        CEE_RazorPayPaymentConnection.CreatePaymentLinkforOpportunity(strCurOppId);
                    }*/                  
                    
                }
                
                List<Opportunity> hrOppList = new List<Opportunity>();
                

                for(Opportunity opp : trigger.new){

                    if(opp.RecordTypeId == HRRecordType){
                    	hrOppList.add(opp);
                	}

                }
                
                
                List<Opportunity> lockRecordsOppList = new List<Opportunity>();

                for(Opportunity opp : trigger.new){
                    if(opp.RecordTypeId == sdpOppRecordType || opp.RecordTypeId == ldpOppRecordType || 
                    opp.RecordTypeId == onlineProgOppRecordType || opp.RecordTypeId == HRRecordType){
                    
                    Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
                    if( opp.StageName == 'Applicant' && opp.StageName != oldOpp.StageName ){
                        lockRecordsOppList.add(opp);
                    }

                    }
                }
                
            	if(hrOppList.size() > 0){
                	CEE_OpportunityTriggerHandler.HROppStageChange(hrOppList,trigger.oldMap);
            	}
                /*if(map_NewOpportuntiesById.keyset().size()>0){
                    CEE_OpportunityTriggerHandler.CreateQuotes(map_NewOpportuntiesById);
                }*/
                if(!oppIdSet.isEmpty()){
                    //CEE_OpportunityTriggerHandler.sendLDPOfferEmailToContact(oppIdSet);
                } 
                if(map_OpportuntiesById.keyset().size()>0){
                    CEE_OpportunityTriggerHandler.ClonetoContacts(map_OpportuntiesById);
                }
                if(lostOpportunity.size() > 0   && !System.isBatch()){
                    CEE_OpportunityTriggerHandler.updateLostOnCloneOpportunity(lostOpportunity);
                }
                if(lockRecordsOppList.size() > 0){
                    CEE_OpportunityTriggerHandler.LockEducationWorkexRecords(lockRecordsOppList, Trigger.oldMap);
                }
                
                List<Opportunity> oppListForLMS2Callout = new List<Opportunity>();

                for(Opportunity opp : trigger.new){
                    if(opp.RecordTypeId == onlineProgOppRecordType){
                    
                    Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
                    if( opp.StageName == 'Student' && opp.StageName != oldOpp.StageName ){
                        oppListForLMS2Callout.add(opp);
                    }

                    }
                }

                CEE_OpportunityTriggerHandler.LMSCalloutForStudentStage(oppListForLMS2Callout, Trigger.oldMap);

                CEE_OpportunityTriggerHandler.unenrolUsersForLostOpportunities(Trigger.new, Trigger.oldMap);


                //CEE_OpportunityTriggerHandler.Sendmailstocandidates(Trigger.newMap);
            }

            if(CEE_OpportunityTriggerhandler.skipAfterUpdate){
                CEE_OpportunityTriggerhandler.skipAfterUpdate= false;
                //CEE_OpportunityTriggerHandler.SendAttachments(Trigger.New, Trigger.OldMap); 
                OpportunityTriggerHandleGrants.sendEmailtoDraftLegal(Trigger.New ,Trigger.Old);
                CEE_OpportunityTriggerhandler.UpdateOwnerID(Trigger.newMap);
                //CEE_OpportunityTriggerhandler.createopplineitems(Trigger.NewMap ,Trigger.OldMap);
                CEE_OpportunityTriggerhandler.updateLeadOppStage(Trigger.NewMap ,Trigger.OldMap);
                Boolean contactFieldsChanged = false;
                for(String OppId : trigger.oldMap.keyset()){
                    if(trigger.newMap.get(OppId).APP_Contact__c != Null &&(trigger.newMap.get(OppId).APP_Company__c != trigger.oldMap.get(OppId).APP_Company__c ||
                                                                            trigger.newMap.get(OppId).APP_Designation__c != trigger.oldMap.get(OppId).APP_Designation__c ||
                                                                            trigger.newMap.get(OppId).Area_of_Specialisation__c != trigger.oldMap.get(OppId).Area_of_Specialisation__c ||
                                                                            trigger.newMap.get(OppId).APP_City__c != trigger.oldMap.get(OppId).APP_City__c ||
                                                                            trigger.newMap.get(OppId).APP_State__c != trigger.oldMap.get(OppId).APP_State__c ||
                                                                            trigger.newMap.get(OppId).APP_Country__c != trigger.oldMap.get(OppId).APP_Country__c ||
                                                                            trigger.newMap.get(OppId).APP_Pincode_New__c != trigger.oldMap.get(OppId).APP_Pincode_New__c ||
                                                                            trigger.newMap.get(OppId).APP_CurrentIndustry__c != trigger.oldMap.get(OppId).APP_CurrentIndustry__c ||
                                                                            trigger.newMap.get(OppId).APP_Gender__c != trigger.oldMap.get(OppId).APP_Gender__c ||
                                                                            trigger.newMap.get(OppId).APP_Pan__c != trigger.oldMap.get(OppId).APP_Pan__c ||
                                                                            trigger.newMap.get(OppId).Continent__c != trigger.oldMap.get(OppId).Continent__c ||
                                                                            trigger.newMap.get(OppId).APP_Prefix_Nominating__c != trigger.oldMap.get(OppId).APP_Prefix_Nominating__c) ) {
                        contactFieldsChanged = true;
                        break;
                    }
                }
                if(contactFieldsChanged) {
                    CEE_OpportunityTriggerHandler.paxFieldUpdate(Trigger.new);
                }
                Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
                for(Opportunity Opp : trigger.new){
                    Boolean autoApprovedNew =  trigger.newMap.get(Opp.Id).Auto_Approved__c;
                    Boolean autoApprovedOld =  trigger.oldMap.get(Opp.Id).Auto_Approved__c;
                    if(trigger.oldMap.get(Opp.id).StageName == 'Applied' && trigger.newMap.get(Opp.id).StageName == 'Offer Open' && autoApprovedNew == true && autoApprovedOld == false){
                        map_NewOpportuntiesById.put(Opp.Id,trigger.newMap.get(Opp.Id));
                    }
                    if(trigger.oldMap.get(opp.id).StageName != trigger.newMap.get(opp.id).StageName && trigger.newMap.get(opp.id).StageName == 'Payment' && trigger.newMap.get(opp.id).APP_NominatedBy__c == 'Sponsored by Company'){
                        map_NewOpportuntiesById.put(Opp.Id,trigger.newMap.get(Opp.Id));
                    }
                    
                }
                

                /*if(map_NewOpportuntiesById.keyset().size()>0){
                    //CEE_OpportunityTriggerHandler.CreateQuotes(map_NewOpportuntiesById);
                    CEE_OpportunityTriggerHandler.createOLIsFromInstallments(map_NewOpportuntiesById);
                    
                }  */              
            }
            
            // Custom logic: After update, create CEE_Participant_Info__c if needed
            List<Opportunity> oppsToCheck = new List<Opportunity>();
            for (Opportunity opp : Trigger.new) {
                Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
                Boolean stageChangedToStudent = oldOpp.StageName != opp.StageName && opp.StageName == 'Student';
                Boolean statusChangedToPaidOffline = oldOpp.Payment_Status__c != opp.Payment_Status__c && opp.Payment_Status__c == 'PAID OFFLINE';
                if (stageChangedToStudent || statusChangedToPaidOffline) {
                    // Check if participant info exists
                    List<CEE_Participant_Info__c> existing = [
                        SELECT Id FROM CEE_Participant_Info__c
                        WHERE (Contact_Name__c = :opp.APP_Contact__c OR Contact_Email_Id__c = :opp.APP_Email__c)
                        AND Program_Name__c = :opp.APP_Product__c
                        LIMIT 1
                    ];
                    if (existing.isEmpty()) {
                        oppsToCheck.add(opp);
                    }
                }
            }
            if (!oppsToCheck.isEmpty()) {
                CEE_OpportunityTriggerHandler.createParticipantInfo(oppsToCheck);
            }
        }
        if(trigger.IsInsert && trigger.isAfter){
            Id opportunityOnlineId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Online Program').getRecordTypeId();
            Id HRRecordType = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('CEE-HR').getRecordTypeId();
            
            /*if(Trigger.new[0].recordtypeId != opportunityOnlineId){
                OpportunitytoOzonetel.PassToOzoneTel(Trigger.new[0].id);
            }*/
            
           List<Opportunity> hrOppList = new List<Opportunity>();
                
            for(Opportunity opp : trigger.new){
                if(opp.RecordTypeId == HRRecordType){
                    hrOppList.add(opp);
                }
            }

        }
        
        if(trigger.isBefore && trigger.isUpdate){
            CEE_OpportunityTriggerHandler.validateB2BClosure(Trigger.new, Trigger.oldMap);
            CEE_OpportunityTriggerHandler.validateStudentConversion(Trigger.new, Trigger.oldMap);
            CEE_OpportunityTriggerHandler.validateNomineeConversion(Trigger.new, Trigger.oldMap);
            CEE_OpportunityTriggerHandler.handleBackwardStageMovement(Trigger.new, Trigger.oldMap);
            CEE_OpportunityTriggerHandler.generateRollNumber(Trigger.new, Trigger.oldMap);
            CEE_OpportunityTriggerHandler.applyEarlyBirdPricebook(Trigger.new, Trigger.oldMap);
            CEE_OpportunityTriggerHandler.validatePriceBookChange(Trigger.new, Trigger.oldMap);
            CEE_OpportunityTriggerHandler.validateCitizenship(Trigger.new, Trigger.oldMap);
            CEE_OpportunityTriggerHandler.determineGSTApplicability(Trigger.new, Trigger.oldMap);
            if(CEE_OpportunityTriggerHandler.skipBeforeUpdate){
                List<Id> oppIds = new List<Id>();
                CEE_OpportunityTriggerHandler.skipBeforeUpdate = false;
                //CEE_OpportunityTriggerhandler.createLead(Trigger.New);
                CEE_OpportunityTriggerHandler.updateProductCode(Trigger.new);
                CEE_OpportunityTriggerhandler.updateOppApplicationStage(Trigger.new);
                if(!System.isFuture() && !System.isBatch()){
                    for(Opportunity opp:Trigger.new){
                        oppIds.add(opp.Id);
                    }
                    if(oppIds.size() > 0){
                        CEE_OpportunityTriggerHandler.updateUTMParameters(oppIds);
                    } 
                }
                
                
            }
            
            
            set<Id> oppIdSet = new set<Id>();
            
            Map<Id,Opportunity>  map_NewOpportuntiesById = new Map<Id,Opportunity>();
            Set<String> allowedFields = new Set<String>{'StageName', 'Description', 'APP_NominatedBy__c','Probability','ExpectedRevenue','Offer_Open_Date__c','UTM_Source__c','OwnerID'};
                for(Opportunity Opp : trigger.new){
                    if(opp.Sub_Stage__c != null && opp.Lost_Sub_Status__c != null){
                        opp.Current_Status__c = opp.StageName + '-' + opp.Sub_Stage__c + '-' + opp.Lost_Sub_Status__c;
                    }
                    else if(opp.Sub_Stage__c != null){
                        opp.Current_Status__c = opp.StageName + '-' + opp.Sub_Stage__c;
                    }
                    else{
                        opp.Current_Status__c = opp.StageName;
                    }
                    Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
                    Set<String> updatedFields = opp.getPopulatedFieldsAsMap().keySet();
                    updatedFields.removeAll(allowedFields);
                    // if((trigger.oldMap.get(opp.id).StageName == 'Application in progress' || trigger.oldMap.get(opp.id).StageName == 'Applied')){
                    //     for(String fieldName:updatedFields){
                    //         if(opp.get(fieldName) != oldOpp.get(fieldName)){
                    //             if(opp.Programme_End_Date__c != null && opp.Programme_End_Date__c < system.today()){
                    //                 System.debug('FieldName>>>'+fieldName);
                    //                 opp.addError('Cannot change the data of Opportunity since Program has been ended');
                    //             }
                                
                    //         }
                    //         else{
                    //             continue;
                    //         }
                    //     }
                    // }
                    system.debug('newmapStagename:'+trigger.newMap.get(opp.id).StageName);
                    system.debug('oldmapStageName:'+trigger.oldMap.get(opp.id).StageName);
                    system.debug('newmapdetails:'+trigger.newMap.get(opp.id).Sub_Stage__c);
                    
                    if(trigger.oldMap.get(opp.id).StageName != trigger.newMap.get(opp.Id).StageName && trigger.newMap.get(opp.id).StageName == 'Payment' && (trigger.newMap.get(opp.id).APP_NominatedBy__c == 'Sponsored by Company' || trigger.newMap.get(opp.id).APP_is_HR_Nominated__c == true)){
                        opp.Sub_Stage__c = 'Invoiced and yet to pay';
                        CEE_OpportunityTriggerHandler.createParticipantInfo(Trigger.New);                    
                    }
                    if(trigger.oldMap.get(opp.id).StageName != trigger.newMap.get(opp.Id).StageName && trigger.newMap.get(opp.id).StageName == 'Student'){
                        CEE_OpportunityTriggerHandler.createParticipantInfo(Trigger.New);
                    }
                    if(trigger.oldMap.get(opp.id).StageName != trigger.newMap.get(opp.Id).StageName && trigger.newMap.get(opp.id).StageName == 'Payment' && (trigger.newMap.get(opp.id).APP_NominatedBy__c == 'Self' || trigger.newMap.get(opp.id).APP_NominatedBy__c == null)){
                        CEE_OpportunityTriggerHandler.createParticipantInfo(Trigger.New);
                    }
                    if(trigger.oldMap.get(opp.id).Sub_Stage__c != 'Withdrew' && trigger.NewMap.get(opp.id).Sub_Stage__c == 'Withdrew'){
                        opp.opportunity_Sub_Stage_Withdrew_Date__c = system.today();
                    }
                    if(trigger.oldMap.get(opp.Id).StageName != trigger.newMap.get(opp.id).StageName){
                        system.debug('Previous Stage'+trigger.oldMap.get(opp.id).StageName);
                        opp.Previous_StageName__c = trigger.oldMap.get(opp.id).StageName;
                        opp.Previous_SubStage__c = trigger.oldMap.get(opp.id).Sub_Stage__c;
                    }
                    
                    
                    oppIdSet.add(opp.id);
                    if(opp.Time_Taken_In_Days__c == null && trigger.oldMap.get(opp.id).StageName == 'Application in progress' && opp.StageName != 'Application in progress'){
                        long dt1 = opp.CreatedDate.getTime();
                        long dt2 = datetime.now().getTime();
                        Long milliseconds = dt2 - dt1;
                        Long seconds = milliseconds / 1000;
                        Long minutes = seconds / 60;
                        opp.Time_Taken_In_Days__c = minutes;
                    }
                    if(opp.Applied_Stage_Date_Time__c == null && trigger.oldMap.get(opp.id).StageName == 'Application in progress' && opp.StageName == 'Applied'){
                        opp.Applied_Stage_Date_Time__c = datetime.now();
                    }
                    if(opp.Applied_Stage_Date_Time__c != null && trigger.oldMap.get(opp.id).StageName != 'Payment' && opp.StageName == 'Payment'){
                        long dt1 = opp.Applied_Stage_Date_Time__c.getTime();
                        long dt2 = datetime.now().getTime();
                        Long milliseconds = dt2 - dt1;
                        Long seconds = milliseconds / 1000;
                        Long minutes = seconds / 60;
                        opp.Applied_to_Payment_In_Minutes__c = minutes;
                    }
                    if(opp.Applied_Stage_Date_Time__c != null && trigger.oldMap.get(opp.id).StageName != 'Offer Accepted' && opp.StageName == 'Offer Accepted'){
                        long dt1 = opp.Applied_Stage_Date_Time__c.getTime();
                        long dt2 = datetime.now().getTime();
                        Long milliseconds = dt2 - dt1;
                        Long seconds = milliseconds / 1000;
                        Long minutes = seconds / 60;
                        opp.Applied_to_Offer_Accepted_In_Minutes__c = minutes;
                    } 
                }
            if(!oppIdSet.isEmpty()){
                list<Opportunity> opportunityList = [Select Id,PriceBook_Program__c,Selected_Program_Total_Fee_Number__c,APP_Product__c,Pricebook2Id from Opportunity Where Id=:oppIdSet];
                set<String> programAndProductSet = new set<String>();
                Map<String,decimal> programAndProductMap = new Map<String,decimal>();
                if(opportunityList.size() > 0){
                    for(Opportunity opp : opportunityList){
                        if(opp.PriceBook_Program__c != null){
                            programAndProductSet.add(opp.PriceBook_Program__c);
                        }
                    }
                    
                }
            }    
        }
        
        if (Trigger.isBefore) {
            if (Trigger.isInsert || Trigger.isUpdate) {
                CEE_OpportunityTriggerHandler.copyRemarksToRemarksTableu(Trigger.new);
            }
        }
        if (Trigger.isAfter) {
            if (Trigger.isUpdate) {
                CEE_OpportunityTriggerHandler.recalculateConvertedOpps(Trigger.new, Trigger.oldMap);                
                CEE_OpportunityTriggerHandler.LXPCalloutForStudentStage(Trigger.new, Trigger.oldMap); //LXP 1.0 Integration callout EE DL - Added by Anitha for ISB-4808
                CEE_OpportunityTriggerHandler.revokeLXPAccessForLostOpportunities(Trigger.new, Trigger.oldMap); //LXP 1.0 Integration callout for revoking access EE DL - Added by Anitha for ISB-4808
                CEE_OpportunityTriggerHandler.triggerEEDLVerification(Trigger.new, Trigger.oldMap);
                CEE_OpportunityTriggerHandler.deleteOLIsOnBackwardMovement(Trigger.new, Trigger.oldMap);
            }
        }
       
    }
}