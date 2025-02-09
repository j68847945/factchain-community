// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FactchainCommunity.sol";

contract FactchainCommunityTest is Test, IFactchainCommunity, IOwnable {
    FactchainCommunity public tmCommunity;
    uint160 lastUintAddress = 0;

    function nextAddress() public returns (address) {
        lastUintAddress += 1;
        return address(lastUintAddress);
    }

    address public owner = nextAddress();
    address public player1 = nextAddress();
    address public player2 = nextAddress();
    address public rater1 = nextAddress();
    address public rater2 = nextAddress();

    function fundReserve() public {
        hoax(owner);
        vm.expectEmit();
        emit ReserveFunded(100);
        (bool result,) = payable(tmCommunity).call{value: 100}("");
        assertTrue(result);
    }

    function setUp() public {
        tmCommunity = new FactchainCommunity({_owner: owner});
        fundReserve();
    }

    function test_createNote_RevertIf_notEnoughEth() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        hoax(player1);
        vm.expectRevert(IFactchainCommunity.InsufficientStake.selector);
        tmCommunity.createNote{value: minimumStakePerNote - 1}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });
    }

    function test_createNote_RevertIf_postUrlInvalid() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        hoax(player1);
        vm.expectRevert(IFactchainCommunity.PostUrlInvalid.selector);
        tmCommunity.createNote{value: minimumStakePerNote}({_postUrl: "", _content: "Something something something"});
        vm.expectRevert(IFactchainCommunity.PostUrlInvalid.selector);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something-something-something-something-something-something-something-something-something-something-something-something-something-something-something",
            _content: "Something something something"
        });
    }

    function test_createNote_RevertIf_contentInvalid() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        hoax(player1);
        vm.expectRevert(IFactchainCommunity.ContentInvalid.selector);
        tmCommunity.createNote{value: minimumStakePerNote}({_postUrl: "https://twitter.com/something", _content: ""});

        vm.expectRevert(IFactchainCommunity.ContentInvalid.selector);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something something"
        });
    }

    function test_createNote() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        (uint32 originalNumberNotes,,,) = tmCommunity.userStats(player1);
        hoax(player1);
        vm.expectEmit();
        emit NoteCreated("https://twitter.com/something", player1, minimumStakePerNote);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });
        (uint32 newNumberNotes,,,) = tmCommunity.userStats(player1);
        assert(newNumberNotes == originalNumberNotes + 1);
    }

    function test_createNote_RevertIf_alreadyExists() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });
        vm.prank(player1);
        vm.expectRevert(IFactchainCommunity.NoteAlreadyExists.selector);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });
    }

    function test_rateNote_RevertIf_ratingInvalid() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        uint256 minimumStakePerRating = tmCommunity.minimumStakePerRating();
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });

        hoax(rater1);
        vm.expectRevert(IFactchainCommunity.RatingInvalid.selector);
        tmCommunity.rateNote{value: minimumStakePerRating}({
            _postUrl: "https://twitter.com/something",
            _creator: player1,
            _rating: 0
        });
        vm.expectRevert(IFactchainCommunity.RatingInvalid.selector);
        tmCommunity.rateNote{value: minimumStakePerRating}({
            _postUrl: "https://twitter.com/something",
            _creator: player1,
            _rating: 6
        });
    }

    function test_rateNot_RevertIf_notEnoughStake() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        uint256 minimumStakePerRating = tmCommunity.minimumStakePerRating();
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });
        hoax(player2);
        vm.expectRevert(IFactchainCommunity.InsufficientStake.selector);
        tmCommunity.rateNote{value: minimumStakePerRating - 1}({
            _postUrl: "https://twitter.com/something",
            _creator: player1,
            _rating: 4
        });
    }

    function test_rateNote_RevertIf_creatorIsRater() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        uint256 minimumStakePerRating = tmCommunity.minimumStakePerRating();
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });

        vm.prank(player1);
        vm.expectRevert(IFactchainCommunity.CantRateOwnNote.selector);
        tmCommunity.rateNote{value: minimumStakePerRating}({
            _postUrl: "https://twitter.com/something",
            _creator: player1,
            _rating: 1
        });
    }

    function test_rateNote_RevertIf_noteDoesNotExist() public {
        uint256 minimumStakePerRating = tmCommunity.minimumStakePerRating();
        hoax(player2);
        vm.expectRevert(IFactchainCommunity.NoteDoesNotExist.selector);
        tmCommunity.rateNote{value: minimumStakePerRating}({
            _postUrl: "https://twitter.com/something",
            _creator: player1,
            _rating: 1
        });
    }

    function test_rateNote_RevertIf_noteAlreadyFinalised() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        uint256 minimumStakePerRating = tmCommunity.minimumStakePerRating();
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });

        vm.prank(owner);
        tmCommunity.finaliseNote({_postUrl: "https://twitter.com/something", _creator: player1, _finalRating: 1});

        hoax(rater1);
        vm.expectRevert(IFactchainCommunity.NoteAlreadyFinalised.selector);
        tmCommunity.rateNote{value: minimumStakePerRating}({
            _postUrl: "https://twitter.com/something",
            _creator: player1,
            _rating: 2
        });
    }

    function test_rateNote() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        uint256 minimumStakePerRating = tmCommunity.minimumStakePerRating();
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });

        (, uint32 originalNumberRatings,,) = tmCommunity.userStats(rater1);
        vm.expectEmit();
        emit NoteRated("https://twitter.com/something", player1, rater1, 1, minimumStakePerRating);
        hoax(rater1);
        tmCommunity.rateNote{value: minimumStakePerRating}({
            _postUrl: "https://twitter.com/something",
            _creator: player1,
            _rating: 1
        });
        (, uint32 newNumberRatings,,) = tmCommunity.userStats(rater1);
        assert(newNumberRatings == originalNumberRatings + 1);
    }

    function test_rateNote_RevertIf_ratingAlreadyExist() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        uint256 minimumStakePerRating = tmCommunity.minimumStakePerRating();
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });

        hoax(rater1);
        tmCommunity.rateNote{value: minimumStakePerRating}({
            _postUrl: "https://twitter.com/something",
            _creator: player1,
            _rating: 1
        });

        hoax(rater1);
        vm.expectRevert(IFactchainCommunity.RatingAlreadyExists.selector);
        tmCommunity.rateNote{value: minimumStakePerRating}({
            _postUrl: "https://twitter.com/something",
            _creator: player1,
            _rating: 2
        });
    }

    function test_finaliseNote_RevertIf_notOwner() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });

        vm.startPrank(rater1);
        vm.expectRevert(IOwnable.NotOwner.selector);
        tmCommunity.finaliseNote({_postUrl: "https://twitter.com/something", _creator: player1, _finalRating: 1});
    }

    function test_finaliseNote_RevertIf_ratingInvalid() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });

        vm.startPrank(owner);
        vm.expectRevert(IFactchainCommunity.RatingInvalid.selector);
        tmCommunity.finaliseNote({_postUrl: "https://twitter.com/something", _creator: player1, _finalRating: 0});
        vm.expectRevert(IFactchainCommunity.RatingInvalid.selector);
        tmCommunity.finaliseNote({_postUrl: "https://twitter.com/something", _creator: player1, _finalRating: 6});
    }

    function test_finaliseNote_RevertIf_notDoesNotExist() public {
        vm.prank(owner);
        vm.expectRevert(IFactchainCommunity.NoteDoesNotExist.selector);
        tmCommunity.finaliseNote({_postUrl: "https://twitter.com/something", _creator: player1, _finalRating: 1});
    }

    function test_finaliseNote() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });

        vm.expectEmit();
        emit NoteFinalised("https://twitter.com/something", player1, 1);
        vm.prank(owner);
        tmCommunity.finaliseNote({_postUrl: "https://twitter.com/something", _creator: player1, _finalRating: 1});
    }

    function test_finaliseNote_RevertIf_noteAlreadyFinalised() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });

        vm.startPrank(owner);
        tmCommunity.finaliseNote({_postUrl: "https://twitter.com/something", _creator: player1, _finalRating: 1});

        vm.expectRevert(IFactchainCommunity.NoteAlreadyFinalised.selector);
        tmCommunity.finaliseNote({_postUrl: "https://twitter.com/something", _creator: player1, _finalRating: 1});
    }

    function test_rewardAndSlashRaters() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        uint256 minimumStakePerRating = tmCommunity.minimumStakePerRating();
        (,, uint96 rater1OldRewards,) = tmCommunity.userStats(rater1);
        (,,, uint96 rater2OldSlash) = tmCommunity.userStats(rater2);

        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });

        hoax(rater1);
        uint256 rater1OriginalBalance = rater1.balance;
        // _rating perfectly matches final rating (1)
        // rater1 should be reward of 2 WEI
        tmCommunity.rateNote{value: minimumStakePerRating}({
            _postUrl: "https://twitter.com/something",
            _creator: player1,
            _rating: 1
        });

        hoax(rater2);
        uint256 rater2OriginalBalance = rater2.balance;
        // wrong rating with maximal delta
        // rater2 should be slashed of 2 WEI
        tmCommunity.rateNote{value: minimumStakePerRating}({
            _postUrl: "https://twitter.com/something",
            _creator: player1,
            _rating: 5
        });

        vm.expectEmit();
        emit RaterRewarded("https://twitter.com/something", player1, rater1, 2, minimumStakePerRating);
        vm.expectEmit();
        emit RaterSlashed("https://twitter.com/something", player1, rater2, 2, minimumStakePerRating);
        vm.prank(owner);
        tmCommunity.finaliseNote({_postUrl: "https://twitter.com/something", _creator: player1, _finalRating: 1});

        (,, uint96 rater1NewRewards,) = tmCommunity.userStats(rater1);
        assert(rater1.balance == rater1OriginalBalance + 2);
        assert(rater1NewRewards == rater1OldRewards + 2);
        (,,, uint96 rater2NewSlash) = tmCommunity.userStats(rater2);
        assert(rater2.balance == rater2OriginalBalance - 2);
        assert(rater2NewSlash == rater2OldSlash + 2);
    }

    function test_rewardCreator() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        (,, uint96 oldRewards,) = tmCommunity.userStats(player1);

        hoax(player1);
        uint256 player1OriginalBalance = player1.balance;
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });

        vm.expectEmit();
        emit CreatorRewarded("https://twitter.com/something", player1, 30, minimumStakePerNote);
        vm.prank(owner);
        tmCommunity.finaliseNote({_postUrl: "https://twitter.com/something", _creator: player1, _finalRating: 5});

        assert(player1.balance == player1OriginalBalance + 30);
        (,, uint96 newRewards,) = tmCommunity.userStats(player1);
        assert(newRewards == oldRewards + 30);
    }

    function test_slashCreator() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        (,,, uint96 oldSlash) = tmCommunity.userStats(player1);

        hoax(player1);
        uint256 player1OriginalBalance = player1.balance;
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: "https://twitter.com/something",
            _content: "Something something something"
        });
        vm.expectEmit();
        emit CreatorSlashed("https://twitter.com/something", player1, 10, minimumStakePerNote);
        vm.prank(owner);
        tmCommunity.finaliseNote({_postUrl: "https://twitter.com/something", _creator: player1, _finalRating: 1});

        assert(player1.balance == player1OriginalBalance - 10);
        (,,, uint96 newSlash) = tmCommunity.userStats(player1);
        assert(newSlash == oldSlash + 10);
    }

    function test_RevertIf_insuficientFundForReward() public {
        uint256 minimumStakePerNote = tmCommunity.minimumStakePerNote();
        uint256 index = 0;
        while (address(tmCommunity).balance > 30) {
            string memory postUrl1 = string.concat("https://twitter.com/something", vm.toString(index));
            hoax(player1);
            tmCommunity.createNote{value: minimumStakePerNote}({
                _postUrl: postUrl1,
                _content: "Something something something"
            });

            vm.prank(owner);
            tmCommunity.finaliseNote({_postUrl: postUrl1, _creator: player1, _finalRating: 5});
            index += 1;
        }

        string memory postUrl2 = string.concat("https://twitter.com/something", vm.toString(index));
        hoax(player1);
        tmCommunity.createNote{value: minimumStakePerNote}({
            _postUrl: postUrl2,
            _content: "Something something something"
        });

        vm.expectRevert(IFactchainCommunity.FailedToReward.selector);
        vm.prank(owner);
        tmCommunity.finaliseNote({_postUrl: postUrl2, _creator: player1, _finalRating: 5});
    }

    function test_setMinimumStakePerNote() public {
        vm.prank(owner);
        tmCommunity.setMinimumStakePerNote(123);
        assert(tmCommunity.minimumStakePerNote() == 123);
    }

    function test_setMinimumStakePerNote_RevertIf_notOwner() public {
        vm.expectRevert(IOwnable.NotOwner.selector);
        vm.prank(player1);
        tmCommunity.setMinimumStakePerNote(123);
    }

    function test_setMinimumStakePerRating() public {
        vm.prank(owner);
        tmCommunity.setMinimumStakePerRating(123);
        assert(tmCommunity.minimumStakePerRating() == 123);
    }

    function test_setMinimumStakePerRating_RevertIf_notOwner() public {
        vm.expectRevert(IOwnable.NotOwner.selector);
        vm.prank(player1);
        tmCommunity.setMinimumStakePerRating(123);
    }
}
