// Copyright 2004-present Facebook. All Rights Reserved.

/* This file provided by Facebook is for non-commercial testing and evaluation
 * purposes only.  Facebook reserves all rights not expressly granted.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "WildeGuessCollectionViewController.h"

#import <ComponentKit/CKCollectionViewDataSource.h>
#import <ComponentKit/CKComponentFlexibleSizeRangeProvider.h>
#import <ComponentKit/CKComponentProvider.h>
#import <ComponentKit/CKDataSourceChangeset.h>
#import <ComponentKit/CKDataSourceConfiguration.h>
#import <WildeGuessKit/Quote.h>
#import <WildeGuessKit/QuoteContext.h>

#import "QuoteComponentFactory.h"
#import <WildeGuessKit/QuoteModelController.h>
#import <WildeGuessKit/QuotesPage.h>

@interface WildeGuessCollectionViewController () <UICollectionViewDelegateFlowLayout>
@end

@implementation WildeGuessCollectionViewController
{
  CKCollectionViewDataSource *_dataSource;
  QuoteModelController *_quoteModelController;
  CKComponentFlexibleSizeRangeProvider *_sizeRangeProvider;
  WildeGuessQuoteComponentProvider _provider;
}

static UICollectionViewLayout *makeLayout() {
  UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
  [flowLayout setScrollDirection:UICollectionViewScrollDirectionVertical];
  [flowLayout setMinimumInteritemSpacing:0];
  [flowLayout setMinimumLineSpacing:0];
  return flowLayout;
}

- (instancetype)init
{
  return [self initWithProvider:&ComponentProvider];
}

- (instancetype)initWithProvider:(WildeGuessQuoteComponentProvider)provider
{
  if (self = [super initWithCollectionViewLayout:makeLayout()]) {
    _sizeRangeProvider = [CKComponentFlexibleSizeRangeProvider providerWithFlexibility:CKComponentSizeRangeFlexibleHeight];
    _quoteModelController = [QuoteModelController new];
    _provider = provider;
    self.title = @"Wilde Guess";
    self.navigationItem.prompt = @"Tap to reveal which quotes are from Oscar Wilde";
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  // Preload images for the component context that need to be used in component preparation. Components preparation
  // happens on background threads but +[UIImage imageNamed:] is not thread safe and needs to be called on the main
  // thread. The preloaded images are then cached on the component context for use inside components.
  NSSet<NSString *> *imageNames = [NSSet setWithObjects:
                                   @"LosAngeles",
                                   @"MarketStreet",
                                   @"Drops",
                                   @"Powell",
                                   nil];
  self.collectionView.backgroundColor = [UIColor whiteColor];
  self.collectionView.delegate = self;
  QuoteContext *context = [[QuoteContext alloc] initWithImageNames:imageNames];

  // Size configuration
  const CKSizeRange sizeRange = [_sizeRangeProvider sizeRangeForBoundingSize:self.collectionView.bounds.size];
  CKDataSourceConfiguration *configuration =
  [[CKDataSourceConfiguration<Quote *, QuoteContext *> alloc] initWithComponentProviderFunc:_provider
                                                                                    context:context
                                                                                  sizeRange:sizeRange];

  // Create the data source
  _dataSource = [[CKCollectionViewDataSource alloc] initWithCollectionView:self.collectionView
                                               supplementaryViewDataSource:nil
                                                             configuration:configuration];
  // Insert the initial section
  CKDataSourceChangeset *initialChangeset =
  [[[CKDataSourceChangesetBuilder dataSourceChangeset]
    withInsertedSections:[NSIndexSet indexSetWithIndex:0]]
   build];
  [_dataSource applyChangeset:initialChangeset mode:CKUpdateModeAsynchronous userInfo:nil];
  [self _enqueuePage:[_quoteModelController fetchNewQuotesPageWithCount:4]];
}

- (void)_enqueuePage:(QuotesPage *)quotesPage
{
  NSArray *quotes = quotesPage.quotes;
  NSInteger position = quotesPage.position;
  NSMutableDictionary<NSIndexPath *, Quote *> *items = [NSMutableDictionary new];
  for (NSInteger i = 0; i < [quotes count]; i++) {
    [items setObject:quotes[i] forKey:[NSIndexPath indexPathForRow:position + i inSection:0]];
  }
  CKDataSourceChangeset *changeset =
  [[[CKDataSourceChangesetBuilder dataSourceChangeset]
    withInsertedItems:items]
   build];
  [_dataSource applyChangeset:changeset mode:CKUpdateModeAsynchronous userInfo:nil];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [_dataSource sizeForItemAtIndexPath:indexPath];
}

- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
  [_dataSource announceWillDisplayCell:cell];
}

- (void)collectionView:(UICollectionView *)collectionView
  didEndDisplayingCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
  [_dataSource announceDidEndDisplayingCell:cell];
}

static CKComponent *ComponentProvider(Quote *quote, QuoteContext *context)
{
  return QuoteComponentFactory(quote, context);
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  if (scrollView.contentSize.height == 0) {
    return;
  }
  if (scrolledToBottomWithBuffer(scrollView.contentOffset, scrollView.contentSize, scrollView.contentInset, scrollView.bounds)) {
    [self _enqueuePage:[_quoteModelController fetchNewQuotesPageWithCount:8]];
  }
}

static BOOL scrolledToBottomWithBuffer(CGPoint contentOffset, CGSize contentSize, UIEdgeInsets contentInset, CGRect bounds)
{
  CGFloat buffer = CGRectGetHeight(bounds) - contentInset.top - contentInset.bottom;
  const CGFloat maxVisibleY = (contentOffset.y + bounds.size.height);
  const CGFloat actualMaxY = (contentSize.height + contentInset.bottom);
  return ((maxVisibleY + buffer) >= actualMaxY);
}

@end
