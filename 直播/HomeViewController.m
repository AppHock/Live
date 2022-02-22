//
//  HomeViewController.m
//  直播
//
//  Created by Hock on 2021/11/14.
//  Copyright © 2021 Hock. All rights reserved.
//

#import "HomeViewController.h"
#import "A_PViewController.h"

@interface HomeViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSMutableArray *modules;
@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"首页";
    self.view.backgroundColor = UIColor.whiteColor;
    [self.view addSubview:self.tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.modules.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    cell.textLabel.text = self.modules[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *title = self.modules[indexPath.row];
    if ([title isEqualToString:@"【FFmpeg】录制pcm"]) {
        A_PViewController *vc = [[A_PViewController alloc] init];
        vc.title = title;
        [self.navigationController pushViewController:vc animated:YES];
    } else if ([title isEqualToString:@"【直播】"]) {
        
    }
}

- (UITableView *)tableView {
    if (!_tableView) {
        CGRect frame = CGRectMake(0, 100, self.view.frame.size.width, self.view.frame.size.height);
        _tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    }
    return _tableView;
}

- (NSMutableArray *)modules {
    if (!_modules) {
        _modules = [NSMutableArray arrayWithArray:@[@"直播",
                                                    @"【FFmpeg】录制pcm",
                                                    @"【FFmpeg】pcm转aac",
                                                    @"【FFmpeg】aac转pcm"]];
    }
    return _modules;
}
@end
