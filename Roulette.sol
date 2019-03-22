pragma solidity ^0.5.0;
// indique la version du compilateur

contract Roulette { 
	// ... 

	// -------------------- variables -----------------------------------------	
	uint public lastRoundTimestamp;
	uint public nextRoundTimestamp; 
	uint _interval; 
	address _creator;

	enum BetType { Single, Odd, Even }
	// romain : pour une raison obscure, lorsqu'il y a un } à la fin de ligne, un ; n'est pas attendu
	struct Bet { 
		BetType betType; 
		address payable player; 
		uint number; 
		uint value; 
	}
	Bet[] public bets;

	event Finished(uint number, uint nextRoundTimestamp);
	// fin des variables

	// -------------------- constructeur --------------------------------------
	// ici encore la syntaxe de la doc est dépréciée, il faut utiliser le constructeur prévu ("constructor(...) { ... }")
	constructor(uint interval) public { 
		_interval = interval; 
		_creator = msg.sender; //msg est le message qui appelle le smart contract
		nextRoundTimestamp = now + _interval; 
	}


	// --------------------- modifieurs de fonction ---------------------------

	// le underscore est un opérateur qui symbolise le code de la fonction modifiée
	// équivalent : si il y n'y a pas d'ether dans la TX require(false) ==> throw (exception), else do ...
    modifier transactionMustContainEther() {
        if (msg.value == 0) require(false);
        _ ;
    }
	// contrairement à ce qui est indiqué dans la doc, il faut mettre un ";" après l'underscore

	// parcourt les paris en cours pour calculer la somme maximale que la banque devra payer si tous les joueurs gagnent
	modifier bankMustBeAbleToPayForBetType(BetType betType) { 
		uint necessaryBalance = 0; 
		for (uint i = 0; i < bets.length; i++) { 
			necessaryBalance += getPayoutForType(bets[i].betType) * bets[i].value; 
		}
		necessaryBalance += getPayoutForType(betType) * msg.value;
		if (necessaryBalance > address(this).balance) require(false); 
		_ ;
	}
	// contrairement à ce qui est indiqué dans la doc, il faut mettre un ";" après l'underscore


	// -------------------- parier -----------------------------------------
	// fonction betSingle publique = appelée par tout le monde
	// plein de modifiers qui vérifient la validité de l'appel
	function betSingle(uint number) public payable transactionMustContainEther() bankMustBeAbleToPayForBetType(BetType.Single) {
		if (number > 36) require(false); // arrête l'éxécution si pb
		bets.push(Bet({
			 betType: BetType.Single, player: msg.sender, number: number, value: msg.value 
		})); 		// parcourt les paris de type single (sur un chiffre) et les ajoute au tableau bets
	}

	function betEven() public payable transactionMustContainEther() bankMustBeAbleToPayForBetType(BetType.Even) {
		bets.push(Bet({
			betType: BetType.Even, player: msg.sender, number: 0, value: msg.value 
		}));
	}

	// --------------------- sorte d'API mais dans la Blockchain -----------------
	// contrairement à ce qui est indiqué dans la doc, le modifier "constant" est déprécié, il faut utiliser "view"
	function getBetsCountAndValue() public view returns(uint, uint) {
		uint value = 0;
		for (uint i = 0; i < bets.length; i++) {
			value += bets[i].value;
		}
		return (bets.length, value); // retourne le nombre de paris et la valeur totale des gains
	}


	// --------------------- faire tourner la roulette --------------------------

	function launch() public {
		if (now < nextRoundTimestamp) require(false);

		//tirrage de nombre aléatoire en utilisant le hash du bloc précédent
		uint number = uint(blockhash(block.number - 1)) % 37;
		
		// on parcourt tous les paris --> prix en gaz ???
		for (uint i = 0; i < bets.length; i++) {
			bool won = false; // a priori non gagnant
			//uint payout = 0; // pas utilisée
			if (bets[i].betType == BetType.Single) { // parie sur les numéros, gagne si bon numéro
				if (bets[i].number == number) {
					won = true;
				} 
			} else if (bets[i].betType == BetType.Even) { //parie sur les blancs, gagne si blanc
				if (number > 0 && number % 2 == 0) {
					won = true;
				}
			} else if (bets[i].betType == BetType.Odd) { // parie sur les noirs, gagne si noir
				if (number > 0 && number % 2 == 1) {
					won = true;
				}
			}
			if (won) {
				bets[i].player.transfer(bets[i].value * getPayoutForType(bets[i].betType)); // apelle get payout coeff
			} 
		}

		// remise à zéro des compteurs
		uint thisRoundTimestamp = nextRoundTimestamp;
		nextRoundTimestamp = thisRoundTimestamp + _interval;
		lastRoundTimestamp = thisRoundTimestamp;
		bets.length = 0;

		emit Finished(number, nextRoundTimestamp); 
	}

	// renvoie le coeff pour le prix gagnant
	// contrairement à ce qui est indiqué dans la doc, le modifier "constant" est déprécié, il faut utiliser "view"
	// contrairement à ce qui est indiqué dans la doc, il fauut mettre le modifier public ou private
	function getPayoutForType(BetType betType) private pure returns(uint) {
		if (betType == BetType.Single) return 35;
		if (betType == BetType.Even || betType == BetType.Odd) return 2;
		return 0;
	}
}