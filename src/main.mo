
import AID "./accountid";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Ext "./ext";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Nat "mo:base/Char";
import Nat32 "mo:base/Nat32";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Trie "mo:base/Trie";
import Trie2D "mo:base/Trie";

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

    //types defined for NFT Transfer
    type NftIndex = Nat32;
    type NftChunk = Text;
    type NftCopies = Nat32;
    type NftMetadata = Text;
    type Nft = {
        index : Nat32; //individual nft identitfier
        minter : Principal; //who minted nft
        owners : [Principal]; //who owns copies of nft wallet IDs
        chunk : NftChunk; //nft chunk in form of Text
        metadata : NftMetadata; //metadata linked with nft , if its there
        copiesOwned : NftCopies; //number of copies of NFT current wallet have
    };

    type NftTransferRequest = {
        index : Nat32; //which nft to transfer
        to : AccountIdentifier; //Principal to whon NFT is getting transferred
        address : Principal; //Wallet Canister ID
        copies : Nat32; //number of copies to get tranferred
        owners : [Principal];
    };

    type NftRecieveRequest = {
        from : Principal; //recieved from whom?
        chunk : NftChunk; //main chunk data of nft
        metadata : NftMetadata; //
        copies : NftCopies; //number of copies received
        owners : [Principal]; //owners wallet Canister IDS
    };

    type NftMintRequest = {
        chunk : NftChunk;
        metadata : NftMetadata;
        copies : NftCopies;
    };

    // type TokenLedger = Trie.Trie<AccountIdentifier, Balance>;
    private stable var nextTokenID : Nat32 = 0;
    private stable var containerToken : Trie2D.Trie2D<TokenIndex, AccountIdentifier, Balance> = Trie.empty();
    private stable var containerMetadata : Trie2D.Trie2D<TokenIndex, Metadata, Balance> = Trie.empty();


    //containers for NFTs in wallet canister , 
    //NFT will be stored in form of chunks of type Text corresponding to Index.
    //with number of copies each Principal will have.
    private stable var nftIndex : Nat32 = 0;
    private stable var containerNft : Trie.Trie<NftIndex, Nft> = Trie.empty();


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


    public shared (message) func whoami() : async Principal {
        return message.caller;
    };

    //function to mint new NFT and store it in Wallet Canister
    public shared (msg) func mintNFT(request : NftMintRequest) : async (Text){
        var principal : Text = "i76lx-xkhlv-bmgqh-iyixq-ganj6-efqfo-kcuup-63yfg-vsamw-bxzh4-sae";
        var admin : Principal = await whoami();
        if(admin != Principal.fromText(principal)){
            return "Unauthrised Call to Wallet!";
        };
        
        var size : Nat32 = Nat32.fromNat(Trie.size(containerNft));
        var buffer : Buffer.Buffer<Principal> = Buffer.Buffer<Principal>(0);
        buffer.add(admin);
        var nft : Nft = {
            index =  size + 1; 
            minter = admin; 
            owners = buffer.toArray(); 
            chunk = request.chunk; 
            metadata = request.metadata;
            copiesOwned = request.copies; 
        };
        containerNft := Trie.put(containerNft, key(size+1), Nat32.equal, nft).0;
        return "Minted Successfully!";
    };


    //function to transfer minted NFT to other wallet Address
    public func sendNFT(request : NftTransferRequest) : async (Text){
        var principal : AccountIdentifier = request.to;
        var address : Principal = request.address;
        var nftId : Nat32 = request.index;
        var tempNFT : Nft = {
            index = nftId; //individual nft identitfier
            minter = Principal.fromText(principal); //who minted nft
            owners = []; //who owns copies of nft wallet IDs
            chunk = ""; //nft chunk in form of Text
            metadata = ""; //metadata linked with nft , if its there
            copiesOwned = 0; //number of copies of NFT current wallet have
        };
        var nft : Nft = Option.get(Trie.find(containerNft, key(nftId), Nat32.equal), tempNFT);
        let receiverWallet = actor(Principal.toText(address)) : actor { receiveNFT : (NftRecieveRequest) -> async (Text)};
        var requestRecieve : NftRecieveRequest = {
            from = Principal.fromText(principal); 
            chunk = nft.chunk; 
            metadata = nft.metadata; 
            copies = 5; //number of copies you want to transfer (there should be a simple logic , that less/or equal copies which user holds can be transferred)
            owners = request.owners;
        };
        return await receiverWallet.receiveNFT(requestRecieve);
    };

    public func receiveNFT(request : NftRecieveRequest) : async (Text){
        var size : Nat32 = Nat32.fromNat(Trie.size(containerNft));
        var nft : Nft = {
            index = size +1; 
            minter = request.from; //there is a mistake here, will correct it later (minter address will be same always , but here its getting changed)
            owners = request.owners;  //not updating owners array for now , as its just an example
            chunk = request.chunk;
            metadata = request.metadata; //metadata linked with nft , if its there
            copiesOwned = request.copies; //number of copies received
        };

        containerNft := Trie.put(containerNft, key(size+1), Nat32.equal, nft).0;
        return "successfull";
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