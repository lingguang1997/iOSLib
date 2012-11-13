//
//  CardexViewController.h
//  Lib
//
//  Created by lingguang1997 on 10/29/12.
//  Copyright (c) 2012 lingguang1997. All rights reserved.
//
@class CardexView;

@interface CardexViewController : UIViewController <CardexDataSource,
                                                    CardexDelegate>

@property (strong, nonatomic) CardexView *cardexView;
@property (strong, nonatomic) NSMutableArray *dataItems;

- (NSUInteger)numberOfItemsInCardexView:(CardexView *)cardexView;
- (UIView *)cardexView:(CardexView *)cardexView
    viewForItemAtIndex:(NSUInteger)index
           reusingView:view;
- (NSUInteger)maxNumberOfVisibleItemsInCardexView:(CardexView *)cardexView;
- (NSUInteger)firstItemIndexInCardexView:(CardexView *)cardexView;
- (CGPoint)firstItemViewCenter:(CardexView *)cardexView;

- (void)cardexViewWillBeginScrollingAnimation:(CardexView *)cardexView;
- (void)cardexViewDidEndScrollingAnimation:(CardexView *)cardexView;
- (void)cardexViewDidScroll:(CardexView *)cardexView;
- (void)cardexViewCurrentItemIndexDidChange:(CardexView *)cardexView;
- (void)cardexViewWillBeginDragging:(CardexView *)cardexView;
- (void)cardexViewDidEndDragging:(CardexView *)cardexView
                  willDecelerate:(BOOL)decelerate;
- (void)cardexViewWillBeginDecelerating:(CardexView *)cardexView;
- (void)cardexViewDidEndDecelerating:(CardexView *)cardexView;

- (void)cardexView:(CardexView *)cardexView didSelectItemAtIndex:(NSInteger)index;

- (CGFloat)cardexViewItemWidth:(CardexView *)cardexView;
- (CATransform3D)cardexView:(CardexView *)cardexView itemTransformForOffset:(CGFloat)offset baseTransform:(CATransform3D)transform;


@end
