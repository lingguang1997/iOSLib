//
//  CardexViewController.h
//  Lib
//
//  Created by lingguang1997 on 10/29/12.
//  Copyright (c) 2012 lingguang1997. All rights reserved.
//
@class CardexView;

@interface CardexViewController : UIViewController <CardexDataSource>

@property (strong, nonatomic) CardexView *cardexView;
@property (strong, nonatomic) NSMutableArray *dataItems;

- (NSUInteger)numberOfItemsInCardexView:(CardexView *)cardexView;
- (UIView *)cardexView:(CardexView *)cardexView
    viewForItemAtIndex:(NSUInteger)index
           reusingView:view;

@end
