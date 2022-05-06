
import Cycles "mo:base/ExperimentalCycles";
import Trie "mo:base/Trie";
import Trie2D "mo:base/Trie";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Hash "mo:base/Hash";
import Array "mo:base/Array";
import Option "mo:base/Option";


import AID "./accountid";
import Ext "./ext";

actor KCMT_token {
    type AccountIdentifier = Ext.AccountIdentifier;
    type SubAccount = Ext.SubAccount;
    type User = Ext.User;
    type Balance = Ext.Balance;
    type TokenIdentifier = Ext.TokenIdentifier;
    type TokenIndex = Ext.TokenIndex;
    type Extension = Ext.Extension;
    type CommonError = Ext.CommonError;
    type NotifyService = Ext.NotifyService;
    
    type BalanceRequest = Ext.BalanceRequest;
    type BalanceResponse = Ext.BalanceResponse;
    type TransferRequest = Ext.TransferRequest;
    type TransferResponse = Ext.TransferResponse;
    type Metadata = Text;
    
    type TokenRequest = {
        metadata : Metadata;
        supply : Balance;
        owner : AccountIdentifier;
    };
    // type TokenLedger = Trie.Trie<AccountIdentifier, Balance>;
    private stable var nextTokenID : Nat32 = 0;
    private stable var containerToken : Trie2D.Trie2D<TokenIndex, AccountIdentifier, Balance> = Trie.empty();
    private stable var containerMetadata : Trie2D.Trie2D<TokenIndex, Metadata, Balance> = Trie.empty();


    // Create a Trie key from Nat32
    //
    private func key(x : Nat32) : Trie.Key<Nat32> {
        return { hash = x; key = x };
    };
    
    // Create a Trie key from Text
    //
    private func keyT(x : Text) : Trie.Key<Text>{
        return {hash = Text.hash(x); key = x};
    };

    public func registerToken(request : TokenRequest) : async (TokenIndex) {
        var tID : TokenIndex = nextTokenID;
        containerToken := Trie2D.put2D<TokenIndex, AccountIdentifier, Balance>(containerToken, key(tID), Nat32.equal, keyT(request.owner), Text.equal, request.supply);
        // containerMetadata := Trie2D.put2D<TokenIndex, Metadata, Balance>(containerMetadata, key(tID), Nat32.equal, keyT(request.metadata), Text.equal, request.metadata);
        nextTokenID := nextTokenID + 1;
        return tID;
    };

    public query func getBalance(request : BalanceRequest) : async (Balance){
        var principal : Text = "i76lx-xkhlv-bmgqh-iyixq-ganj6-efqfo-kcuup-63yfg-vsamw-bxzh4-sae";
        if (Ext.TokenIdentifier.isPrincipal(request.token, Principal.fromText(principal)) == false) {
			return 0;
		};

        var tID : TokenIndex = Ext.TokenIdentifier.getIndex(request.token);
        var aid : AccountIdentifier = Ext.User.toAID(request.user);

        var temp : Trie.Trie<AccountIdentifier, Balance> = Trie.empty();
        var trie = Option.get(Trie.find(containerToken, key(tID), Nat32.equal), temp);
        var zero : Nat = 0;
        var balance : Balance = Option.get(Trie.find(trie, keyT(aid), Text.equal), zero);
        return balance;
    };

    public query func totalToken() : async (Nat){
        return Trie.size(containerToken);
    };

    public query func cycleBalance() : async Nat{
        return Cycles.balance();
    };


};