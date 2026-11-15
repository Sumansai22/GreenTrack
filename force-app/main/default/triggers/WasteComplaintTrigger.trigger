/**
 * @description Master trigger on Waste_Complaint__c routing DML events to WasteComplaintTriggerHandler.
 * Implements strict recursion protection on updates.
 */
trigger WasteComplaintTrigger on Waste_Complaint__c (
    before insert,
    after insert,
    before update,
    after update,
    after delete,
    after undelete
) {
    WasteComplaintTriggerHandler handler = new WasteComplaintTriggerHandler();

    if (Trigger.isBefore && Trigger.isInsert) {
        handler.beforeInsert(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isInsert) {
        handler.afterInsert(Trigger.new, Trigger.newMap);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        if (!WasteComplaintTriggerHandler.isTriggerExecuting) {
            WasteComplaintTriggerHandler.isTriggerExecuting = true;
            try {
                handler.afterUpdate(Trigger.new, Trigger.oldMap);
            } finally {
                WasteComplaintTriggerHandler.isTriggerExecuting = false;
            }
        }
    } else if (Trigger.isAfter && Trigger.isDelete) {
        handler.afterDelete(Trigger.old);
    } else if (Trigger.isAfter && Trigger.isUndelete) {
        handler.afterUndelete(Trigger.new);
    }
}
