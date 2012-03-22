//
//  RKInMemoryEntityCache.h
//  RestKit
//
//  Created by Jeff Arena on 1/24/12.
//  Copyright (c) 2012 RestKit. All rights reserved.
//

#import <CoreData/CoreData.h>

/**
 Instances of RKInMemoryEntityCache provide an interface for the storage and retrieval of
 NSManagedObject instances stored in memory by attribute.
 */
@interface RKInMemoryEntityCache : NSObject

/**
 */
- (NSMutableDictionary *)cachedObjectsForEntity:(NSEntityDescription *)entity
                                    byAttribute:(NSString *)attributeName
                                      inContext:(NSManagedObjectContext *)managedObjectContext;

/**
 */
- (NSManagedObject *)cachedObjectForEntity:(NSEntityDescription *)entity
                             withAttribute:(NSString *)attributeName
                                     value:(id)attributeValue
                                 inContext:(NSManagedObjectContext *)managedObjectContext;

/**
 */
- (void)cacheObjectsForEntity:(NSEntityDescription *)entity
                  byAttribute:(NSString *)attributeName
                    inContext:(NSManagedObjectContext *)managedObjectContext;

/**
 */
- (void)cacheObject:(NSManagedObject *)managedObject
        byAttribute:(NSString *)attributeName
          inContext:(NSManagedObjectContext *)managedObjectContext;

/**
 */
- (void)cacheObject:(NSEntityDescription *)entity
        byAttribute:(NSString *)attributeName
              value:(id)primaryKeyValue
          inContext:(NSManagedObjectContext *)managedObjectContext;

/**
 */
- (void)expireCacheEntryForObject:(NSManagedObject *)managedObject
                      byAttribute:(NSString *)attributeName
                        inContext:(NSManagedObjectContext *)managedObjectContext;

/**
 */
- (void)expireCacheEntriesForEntity:(NSEntityDescription *)entity;

@end
