//
//  TUITableViewFastLiveResizingContext.h
//  Maipo
//
//  Created by 吴天 on 2018/2/5.
//  Copyright © 2018年 Wutian. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TUITableViewFastLiveResizingContext : NSObject

- (instancetype)initWithWillStartLiveResizingTableView:(TUITableView *)tableView;

- (void)endLiveResizing;

@end
