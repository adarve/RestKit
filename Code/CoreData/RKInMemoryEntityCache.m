//
//  RKInMemoryEntityCache.m
//  RestKit
//
//  Created by Jeff Arena on 1/24/12.
//  Copyright (c) 2012 RestKit. All rights reserved.
//

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#import "RKInMemoryEntityCache.h"
#import "NSManagedObject+ActiveRecord.h"
#import "../ObjectMapping/RKObjectPropertyInspector.h"
#import "RKObjectPropertyInspector+CoreData.h"
#import "RKLog.h"

// Set Logging Component
#undef RKLogComponent
#define RKLogComponent lcl_cRestKitCoreData

@interface RKInMemoryEntityCache ()
@property(nonatomic, retain) NSMutableDictionary *entityCache;

- (BOOL)shouldCoerceAttributeToString:(NSString *)attribute forEntity:(NSEntityDescription *)entity;
- (NSManagedObject *)objectWithID:(NSManagedObjectID *)objectID inContext:(NSManagedObjectContext *)managedObjectContext;
@end

@implementation RKInMemoryEntityCache

@synthesize entityCache;

- (id)init {
    self = [super init];
    if (self) {
        entityCache = [[NSMutableDictionary alloc] init];
#if TARGET_OS_IPHONE
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveMemoryWarning)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
#endif
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [entityCache release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextObjectsDidChangeNotification
                                                  object:nil];
    [entityCache removeAllObjects];
}

- (NSMutableDictionary *)cachedObjectsForEntity:(NSEntityDescription *)entity
                                    byAttribute:(NSString *)attributeName
                                      inContext:(NSManagedObjectContext *)managedObjectContext {
    NSAssert(entity, @"Cannot retrieve cached objects without an entity");
    NSAssert(attributeName, @"Cannot retrieve cached objects without an attributeName");
    NSAssert(managedObjectContext, @"Cannot retrieve cached objects without a managedObjectContext");

    NSMutableDictionary *cachedObjectsForEntity = [entityCache objectForKey:entity.name];
    if (cachedObjectsForEntity == nil) {
        [self cacheObjectsForEntity:entity byAttribute:attributeName inContext:managedObjectContext];
        cachedObjectsForEntity = [entityCache objectForKey:entity.name];
    }
    return cachedObjectsForEntity;
}

- (NSManagedObject *)cachedObjectForEntity:(NSEntityDescription *)entity
                             withAttribute:(NSString *)attributeName
                                     value:(id)attributeValue
                                 inContext:(NSManagedObjectContext *)managedObjectContext {
    NSAssert(entity, @"Cannot retrieve a cached object without an entity");
    NSAssert(attributeName, @"Cannot retrieve a cached object without a mapping");
    NSAssert(attributeValue, @"Cannot retrieve a cached object without a primaryKeyValue");
    NSAssert(managedObjectContext, @"Cannot retrieve a cached object without a managedObjectContext");

    NSMutableDictionary *cachedObjectsForEntity = [self cachedObjectsForEntity:entity
                                                                   byAttribute:attributeName
                                                                     inContext:managedObjectContext];

    // NOTE: We coerce the primary key into a string (if possible) for convenience. Generally
    // primary keys are expressed either as a number of a string, so this lets us support either case interchangeably
    id lookupValue = [attributeValue respondsToSelector:@selector(stringValue)] ? [attributeValue stringValue] : attributeValue;
    NSManagedObjectID *objectID = [cachedObjectsForEntity objectForKey:lookupValue];
    NSManagedObject *object = nil;
    if (objectID) {
        object = [self objectWithID:objectID inContext:managedObjectContext];
    }
    return object;
}

- (void)cacheObjectsForEntity:(NSEntityDescription *)entity
                  byAttribute:(NSString *)attributeName
                    inContext:(NSManagedObjectContext *)managedObjectContext {
    NSAssert(entity, @"Cannot cache objects without an entity");
    NSAssert(attributeName, @"Cannot cache objects without an attributeName");
    NSAssert(managedObjectContext, @"Cannot cache objects without a managedObjectContext");

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    [fetchRequest setResultType:NSManagedObjectIDResultType];

    NSArray *objectIds = [NSManagedObject executeFetchRequest:fetchRequest inContext:managedObjectContext];
    [fetchRequest release];

    RKLogInfo(@"Caching all %ld %@ objectsIDs to thread local storage", (long) [objectIds count], entity.name);
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    if ([objectIds count] > 0) {
        BOOL coerceToString = [self shouldCoerceAttributeToString:attributeName forEntity:entity];
        for (NSManagedObjectID* theObjectID in objectIds) {
            NSManagedObject* theObject = [self objectWithID:theObjectID inContext:managedObjectContext];
            id attributeValue = [theObject valueForKey:attributeName];
            // Coerce to a string if possible
            attributeValue = coerceToString ? [attributeValue stringValue] : attributeValue;
            if (attributeValue) {
                [dictionary setObject:theObjectID forKey:attributeValue];
            }
        }
    }
    [entityCache setObject:dictionary forKey:entity.name];

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(objectsDidChange:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:managedObjectContext];
}

- (void)cacheObject:(NSManagedObject *)managedObject byAttribute:(NSString *)attributeName inContext:(NSManagedObjectContext *)managedObjectContext {
    NSAssert(managedObject, @"Cannot cache an object without a managedObject");
    NSAssert(attributeName, @"Cannot cache an object without a mapping");
    NSAssert(managedObjectContext, @"Cannot cache an object without a managedObjectContext");

    NSManagedObjectID *objectID = [managedObject objectID];
    if (objectID) {
        NSEntityDescription *entity = managedObject.entity;
        BOOL coerceToString = [self shouldCoerceAttributeToString:attributeName forEntity:entity];
        id attributeValue = [managedObject valueForKey:attributeName];
        // Coerce to a string if possible
        attributeValue = coerceToString ? [attributeValue stringValue] : attributeValue;
        if (attributeValue) {
            NSMutableDictionary *cachedObjectsForEntity = [self cachedObjectsForEntity:entity
                                                                           byAttribute:attributeName
                                                                             inContext:managedObjectContext];
            [cachedObjectsForEntity setObject:objectID forKey:attributeValue];
        }
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(objectsDidChange:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:managedObjectContext];
}

- (void)cacheObject:(NSEntityDescription *)entity byAttribute:(NSString *)attributeName value:(id)attributeValue inContext:(NSManagedObjectContext *)managedObjectContext {
    NSAssert(entity, @"Cannot cache an object without an entity");
    NSAssert(attributeName, @"Cannot cache an object without a mapping");
    NSAssert(managedObjectContext, @"Cannot cache an object without a managedObjectContext");

    // NOTE: We coerce the primary key into a string (if possible) for convenience. Generally
    // primary keys are expressed either as a number or a string, so this lets us support either case interchangeably
    id lookupValue = [attributeValue respondsToSelector:@selector(stringValue)] ? [attributeValue stringValue] : attributeValue;

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchLimit:1];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"%K = %@", attributeName, lookupValue]];
    [fetchRequest setResultType:NSManagedObjectIDResultType];

    NSArray *objectIds = [NSManagedObject executeFetchRequest:fetchRequest inContext:managedObjectContext];
    [fetchRequest release];

    NSManagedObjectID *objectID = nil;
    if ([objectIds count] > 0) {
        objectID = [objectIds objectAtIndex:0];
        if (objectID && lookupValue) {
            NSMutableDictionary *cachedObjectsForEntity = [self cachedObjectsForEntity:entity
                                                                           byAttribute:attributeName
                                                                             inContext:managedObjectContext];
            [cachedObjectsForEntity setObject:objectID forKey:lookupValue];
        }
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(objectsDidChange:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:managedObjectContext];
}

- (void)expireCacheEntryForObject:(NSManagedObject *)managedObject byAttribute:(NSString *)attributeName inContext:(NSManagedObjectContext *)managedObjectContext {
    NSAssert(managedObject, @"Cannot expire cache entry for an object without a managedObject");
    NSAssert(attributeName, @"Cannot expire cache entry for an object without a mapping");
    NSAssert(managedObjectContext, @"Cannot expire cache entry for an object without a managedObjectContext");

    NSEntityDescription *entity = managedObject.entity;
    BOOL coerceToString = [self shouldCoerceAttributeToString:attributeName forEntity:entity];
    id attributeValue = [managedObject valueForKey:attributeName];
    // Coerce to a string if possible
    attributeValue = coerceToString ? [attributeValue stringValue] : attributeValue;
    if (attributeValue) {
        NSMutableDictionary *cachedObjectsForEntity = [self cachedObjectsForEntity:entity
                                                                       byAttribute:attributeName
                                                                         inContext:managedObjectContext];
        [cachedObjectsForEntity removeObjectForKey:attributeValue];

        if ([cachedObjectsForEntity count] == 0) {
            [self expireCacheEntriesForEntity:entity];
        }
    }
}

- (void)expireCacheEntriesForEntity:(NSEntityDescription *)entity {
    NSAssert(entity, @"Cannot expire cache entry for an entity without an entity");
    RKLogTrace(@"About to expire cache for entity name=%@", entity.name);
    [entityCache removeObjectForKey:entity.name];
}


#pragma mark Helper Methods

- (BOOL)shouldCoerceAttributeToString:(NSString *)attribute forEntity:(NSEntityDescription *)entity {
    Class attributeType = [[RKObjectPropertyInspector sharedInspector] typeForProperty:attribute ofEntity:entity];
    return [attributeType instancesRespondToSelector:@selector(stringValue)];
}

- (NSManagedObject *)objectWithID:(NSManagedObjectID *)objectID inContext:(NSManagedObjectContext *)managedObjectContext {
    NSAssert(objectID, @"Cannot fetch a managedObject with a nil objectID");
    NSAssert(managedObjectContext, @"Cannot fetch a managedObject with a nil managedObjectContext");
    return [managedObjectContext objectWithID:objectID];
}


#pragma mark Notifications

- (void)objectsDidChange:(NSNotification *)notification {
	NSDictionary *userInfo = notification.userInfo;
	NSSet *insertedObjects = [userInfo objectForKey:NSInsertedObjectsKey];
    NSSet *deletedObjects = [userInfo objectForKey:NSDeletedObjectsKey];
    RKLogTrace(@"insertedObjects=%@, deletedObjects=%@", insertedObjects, deletedObjects);

    NSMutableSet *entitiesToExpire = [NSMutableSet set];
	for (NSManagedObject *object in insertedObjects) {
        [entitiesToExpire addObject:object.entity];
	}

    for (NSManagedObject *object in deletedObjects) {
        [entitiesToExpire addObject:object.entity];
	}

    for (NSEntityDescription *entity in entitiesToExpire) {
        [self expireCacheEntriesForEntity:entity];
    }
}

@end
