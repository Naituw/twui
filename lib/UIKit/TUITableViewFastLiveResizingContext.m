//
//  TUITableViewFastLiveResizingContext.m
//  Maipo
//
//  Created by 吴天 on 2018/2/5.
//  Copyright © 2018年 Wutian. All rights reserved.
//

#import "TUITableViewFastLiveResizingContext.h"

@interface TUITableViewFastLiveResizingContext () <TUITableViewDelegate, TUITableViewDataSource>
{
    struct {
        unsigned int reloadingTableView;
    } _flags;
}

@property (nonatomic, weak) TUITableView * tableView;
@property (nonatomic, weak) id<TUITableViewDataSource> originalTableViewDatasource;
@property (nonatomic, weak) id<TUITableViewDelegate> originalTableViewDelegate;

@property (nonatomic, strong) TUIFastIndexPath * initialFirstVisibleIndexPath;
@property (nonatomic, assign) CGFloat initialRelativeOffset;
@property (nonatomic, assign) NSUInteger initialVisibleCellsCount;
@property (nonatomic, assign) TUIScrollViewIndicatorVisibility initialVerticalScrollIndicatorVisibility;
@property (nonatomic, assign) TUIScrollViewIndicatorVisibility initialHorizontalScrollIndicatorVisibility;

// Mapping Strategy
@property (nonatomic, strong) NSArray<NSNumber *> * mappedSectionInfos;

@end

@implementation TUITableViewFastLiveResizingContext

- (instancetype)initWithWillStartLiveResizingTableView:(TUITableView *)tableView
{
    if (self = [self init]) {
        _tableView = tableView;
        _originalTableViewDelegate = tableView.delegate;
        _originalTableViewDatasource = tableView.dataSource;
        
        [self _takeOverTableViewStates];
    }
    return self;
}

- (void)endLiveResizing
{
    [_tableView reloadDataMaintainingVisibleIndexPath:_initialFirstVisibleIndexPath relativeOffset:_initialRelativeOffset];
}

- (void)_takeOverTableViewStates
{
    if (_tableView.delegate == _originalTableViewDelegate) {
        [self _updateMappingStrategy];
        
        _tableView.userInteractionEnabled = NO;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.verticalScrollIndicatorVisibility = TUIScrollViewIndicatorVisibleNever;
        _tableView.horizontalScrollIndicatorVisibility = TUIScrollViewIndicatorVisibleNever;
        
        _flags.reloadingTableView = YES;
        [_tableView reloadDataMaintainingVisibleIndexPath:[TUIFastIndexPath indexPathForRow:0 inSection:0] relativeOffset:[self _currentTableViewRelativeOffset]];
        _flags.reloadingTableView = NO;
    }
}

- (void)_restoreTableViewStates
{
    _tableView.userInteractionEnabled = YES;
    _tableView.delegate = _originalTableViewDelegate;
    _tableView.dataSource = _originalTableViewDatasource;
    _tableView.verticalScrollIndicatorVisibility = _initialVerticalScrollIndicatorVisibility;
    _tableView.horizontalScrollIndicatorVisibility = _initialHorizontalScrollIndicatorVisibility;
}

- (CGFloat)_currentTableViewRelativeOffset
{
    NSArray * indexPaths = [[_tableView indexPathsForVisibleRows] sortedArrayUsingSelector:@selector(compare:)];
    TUIFastIndexPath * indexPath = indexPaths.firstObject;
    CGRect rect = [_tableView rectForRowAtIndexPath:indexPath];
    CGFloat offset = rect.size.height + (_tableView.contentOffset.y - _tableView.visibleRect.size.height + rect.origin.y);
    return -offset;
}

#pragma mark - Mapping Strategy

- (void)_updateMappingStrategy
{
    _initialRelativeOffset = [self _currentTableViewRelativeOffset];
    _initialVerticalScrollIndicatorVisibility = _tableView.verticalScrollIndicatorVisibility;
    _initialHorizontalScrollIndicatorVisibility = _tableView.horizontalScrollIndicatorVisibility;
    
    NSArray * indexPaths = [[_tableView indexPathsForVisibleRows] sortedArrayUsingSelector:@selector(compare:)];
    _initialFirstVisibleIndexPath = [indexPaths firstObject];
    _initialVisibleCellsCount = [indexPaths count];
    
    NSUInteger preferredRowCount = MAX(_initialVisibleCellsCount * 2, 10);
    
    NSMutableArray<NSNumber *> * mappedInfos = [NSMutableArray array];
    
    TUIFastIndexPath * anchorIndexPath = _initialFirstVisibleIndexPath;
    
    while (preferredRowCount > 0 && anchorIndexPath) {
        NSUInteger rowCount = [_tableView numberOfRowsInSection:anchorIndexPath.section];
        NSUInteger sectionRemainRowCount = rowCount - anchorIndexPath.row;
        NSUInteger mappedRowCount = MIN(preferredRowCount, sectionRemainRowCount);
        [mappedInfos addObject:@(mappedRowCount)];
        preferredRowCount -= mappedRowCount;
        
        if (preferredRowCount > 0) {
            // find next available section
            NSUInteger section = anchorIndexPath.section;
            anchorIndexPath = nil;
            
            NSMutableArray<NSNumber *> * zeroRowSections = [NSMutableArray array];
            
            while ([_tableView numberOfSections] > (section + 1)) {
                if ([_tableView numberOfRowsInSection:section + 1] > 0) {
                    anchorIndexPath = [TUIFastIndexPath indexPathForRow:0 inSection:section + 1];
                    break;
                } else {
                    [zeroRowSections addObject:@0];
                    section++;
                }
            }
            
            if (anchorIndexPath) {
                [mappedInfos addObjectsFromArray:zeroRowSections];
            }
        }
    }
    
    _mappedSectionInfos = mappedInfos;
}

#pragma mark - Delegate & Datasource Proxing

- (NSInteger)_mappedSectionFromOriginalSection:(NSInteger)section
{
    if (section < _initialFirstVisibleIndexPath.section) {
        return -1;
    }
    NSInteger result = section - _initialFirstVisibleIndexPath.section;
    if (result >= _mappedSectionInfos.count) {
        return -1;
    }
    return result;
}

- (TUIFastIndexPath *)_mappedIndexPathFromOriginalIndexPath:(TUIFastIndexPath *)originalIndexPath
{
    NSInteger mappedSection = [self _mappedSectionFromOriginalSection:originalIndexPath.section];
    if (mappedSection < 0) {
        return nil;
    }
    
    if ([_initialFirstVisibleIndexPath compare:originalIndexPath] == NSOrderedDescending) {
        return nil;
    }
    
    NSInteger row = originalIndexPath.row;
    if (mappedSection == 0) {
        row = originalIndexPath.row - _initialFirstVisibleIndexPath.row;
    }
    
    if (row < 0) {
        return nil;
    }
    
    return [TUIFastIndexPath indexPathForRow:row inSection:mappedSection];
}

- (TUIFastIndexPath *)_originalIndexPathFromMappedIndexPath:(TUIFastIndexPath *)mappedIndexPath
{
    NSInteger row = mappedIndexPath.row;
    if (mappedIndexPath.section == 0) {
        row = row + _initialFirstVisibleIndexPath.row;
    }
    NSInteger section = _initialFirstVisibleIndexPath.section + mappedIndexPath.section;
    
    return [TUIFastIndexPath indexPathForRow:row inSection:section];
}

- (void)tableViewWillReloadData:(TUITableView *)tableView
{
    if (!_flags.reloadingTableView) {
        [self _restoreTableViewStates];
    }
}

- (void)tableViewDidReloadData:(TUITableView *)tableView
{
    if (!_flags.reloadingTableView) {
        [self _updateMappingStrategy];
        [self _takeOverTableViewStates];
    }
}

- (CGFloat)tableView:(TUITableView *)tableView heightForRowAtIndexPath:(TUIFastIndexPath *)indexPath
{
    TUIFastIndexPath * originalIndexPath = [self _originalIndexPathFromMappedIndexPath:indexPath];
    return [_originalTableViewDelegate tableView:tableView heightForRowAtIndexPath:originalIndexPath];
}

- (NSInteger)numberOfSectionsInTableView:(TUITableView *)tableView
{
    return _mappedSectionInfos.count;
}

- (NSInteger)tableView:(TUITableView *)table numberOfRowsInSection:(NSInteger)section
{
    return [_mappedSectionInfos[section] integerValue];
}

- (TUITableViewCell *)tableView:(TUITableView *)tableView cellForRowAtIndexPath:(TUIFastIndexPath *)indexPath
{
    TUIFastIndexPath * originalIndexPath = [self _originalIndexPathFromMappedIndexPath:indexPath];
    return [_originalTableViewDatasource tableView:tableView cellForRowAtIndexPath:originalIndexPath];
}

@end
