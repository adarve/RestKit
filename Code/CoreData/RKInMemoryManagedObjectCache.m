//
//  RKInMemoryManagedObjectCache.m
//  RestKit
//
//  Created by Jeff Arena on 1/24/12.
//  Copyright (c) 2012 RestKit. All rights reserved.
//

#import "RKInMemoryManagedObjectCache.h"
#import "RKLog.h"

// Set Logging Component
#undef RKLogComponent
#define RKLogComponent lcl_cRestKitCoreData

static NSString* const RKManagedObjectStoreThreadDictionaryEntityCacheKey = @"RKManagedObjectStoreThreadDictionaryEntityCacheKey";

@interface RKInMemoryManagedObjectCache ()
@property (nonatomic, retain) RKInMemoryEntityCache *cache;
@end

@implementation RKInMemoryManagedObjectCache

@synthesize cache;

- (id)init
{
    self = [super init];
    if (self) {
        cache = [[RKInMemoryEntityCache alloc] init];
    }
    
    return self;
}

- (void)dealloc {
    [cache release];
    cache = nil;
    
    [super dealloc];
}

- (NSManagedObject *)findInstanceOfEntity:(NSEntityDescription *)entity
                  withPrimaryKeyAttribute:(NSString *)primaryKeyAttribute
                                    value:(id)primaryKeyValue
                   inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    NSAssert(entity, @"Cannot find existing managed object without a target class");
    NSAssert(primaryKeyAttribute, @"Cannot find existing managed object instance without mapping");
    NSAssert(primaryKeyValue, @"Cannot find existing managed object by primary key without a value");
    NSAssert(managedObjectContext, @"Cannot find existing managed object with a context");
    return [cache cachedObjectForEntity:entity withAttribute:primaryKeyAttribute value:primaryKeyValue inContext:managedObjectContext];
}

@end
