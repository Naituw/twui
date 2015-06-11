//
//  TUIAppearance.h
//  TwUI
//
//  Created by Wutian on 14/8/3.
//
//

#import <Foundation/Foundation.h>

@interface TUIAppearance : NSObject

@property (copy, readonly) NSString * name;

- (instancetype)initWithAppearanceNamed:(NSString *)name;
+ (instancetype)appearanceNamed:(NSString *)name;

@end

extern NSString *const TUIAppearanceNameDark;
extern NSString *const TUIAppearanceNameLight;

@interface TUIAppearance (Convenience)

+ (instancetype)darkAppearance;
+ (instancetype)lightAppearance;

@end