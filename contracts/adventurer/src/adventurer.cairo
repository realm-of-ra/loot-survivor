use core::serde::Serde;
use integer::{
    U128IntoFelt252, Felt252IntoU256, Felt252TryIntoU64, U256TryIntoFelt252, u256_from_felt252,
};
use traits::{TryInto, Into};
use option::OptionTrait;
use debug::PrintTrait;

use pack::pack::{
    pack_value, unpack_value, U256TryIntoU32, U256TryIntoU16, U256TryIntoU8, U256TryIntoU64
};
use pack::constants::{MASK_16, pow, MASK_8, MASK_BOOL, mask};

use lootitems::loot::{Loot, ItemTrait, ItemUtils};
use lootitems::statistics::constants;

use super::exploration::ExploreUtils;
use super::beasts::BeastUtils;
use super::obstacles::ObstacleUtils;
use super::constants::{discovery_constants, beast_constants};

use super::item_meta::LootStatistics;

#[derive(Drop, Copy, Serde)]
struct Adventurer {
    last_action: u16, // 3 bits
    health: u16, // 9 bits     
    xp: u16, // 15 bits
    // Physical
    strength: u8, // 5 bits
    dexterity: u8, //  5 bits
    vitality: u8, //  5 bits
    // Mental
    intelligence: u8, //  5 bits
    wisdom: u8, //  5 bits
    charisma: u8, //  5 bits
    // equipped
    gold: u16, // 9 bits
    weapon: LootStatistics, // 24 bits
    chest: LootStatistics, // 24 bits
    head: LootStatistics, // 24 bits
    waist: LootStatistics, // 24 bits
    foot: LootStatistics, // 24 bits
    hand: LootStatistics, // 24 bits
    neck: LootStatistics, // 24 bits
    ring: LootStatistics, // 24 bits
    // Beast health
    beast_health: u16,
    stat_upgrade_available: u8,
}

trait Actions {
    fn new(starting_item: u8, block_number: u64) -> Adventurer;
    fn pack(self: Adventurer) -> felt252;
    fn unpack(packed: felt252) -> Adventurer;

    fn explore(ref self: Adventurer, adventurer_entropy: u64, game_entropy: u64) -> Adventurer;
    fn attack(ref self: Adventurer, adventurer_entropy: u64, game_entropy: u64) -> Adventurer;
    fn flee(ref self: Adventurer, adventurer_entropy: u64, game_entropy: u64) -> Adventurer;

    fn add_health(ref self: Adventurer, value: u16) -> Adventurer;
    fn deduct_health(ref self: Adventurer, value: u16) -> Adventurer;

    // gold
    fn increase_gold(ref self: Adventurer, value: u16) -> Adventurer;

    // TODO: tests
    fn deduct_gold(ref self: Adventurer, value: u16) -> Adventurer;
    fn check_gold(self: Adventurer, value: u16) -> bool;

    // xp
    fn increase_adventurer_xp(ref self: Adventurer, value: u16) -> Adventurer;
    fn increase_item_xp(ref self: Adventurer, value: u16) -> Adventurer;

    // stats
    fn add_strength(ref self: Adventurer, value: u8) -> Adventurer;
    fn add_dexterity(ref self: Adventurer, value: u8) -> Adventurer;
    fn add_vitality(ref self: Adventurer, value: u8) -> Adventurer;
    fn add_intelligence(ref self: Adventurer, value: u8) -> Adventurer;
    fn add_wisdom(ref self: Adventurer, value: u8) -> Adventurer;
    fn add_charisma(ref self: Adventurer, value: u8) -> Adventurer;

    // This is generic and can be used for all items
    fn add_item(ref self: Adventurer, value: LootStatistics) -> Adventurer;

    // TODO: Do we keep these as helpers? We use in add_items
    fn add_weapon(ref self: Adventurer, value: LootStatistics) -> Adventurer;
    fn add_chest(ref self: Adventurer, value: LootStatistics) -> Adventurer;
    fn add_head(ref self: Adventurer, value: LootStatistics) -> Adventurer;
    fn add_waist(ref self: Adventurer, value: LootStatistics) -> Adventurer;
    fn add_foot(ref self: Adventurer, value: LootStatistics) -> Adventurer;
    fn add_hand(ref self: Adventurer, value: LootStatistics) -> Adventurer;
    fn add_neck(ref self: Adventurer, value: LootStatistics) -> Adventurer;
    fn add_ring(ref self: Adventurer, value: LootStatistics) -> Adventurer;

    // beast 
    fn deduct_beast_health(ref self: Adventurer, amount: u16) -> Adventurer;

    // we just add the beast -> the beast is deterministic off the xp
    fn add_beast(ref self: Adventurer, value: u16) -> Adventurer;
    fn in_battle(self: Adventurer) -> bool;

    fn luck(self: Adventurer) -> u8;

    fn get_beast(self: Adventurer) -> u8;

    fn get_level(self: Adventurer) -> u8;

    fn is_slot_free(self: Adventurer, item: LootStatistics) -> bool;

    fn get_item_at_slot(self: Adventurer, item: LootStatistics) -> LootStatistics;
}

impl AdventurerActions of Actions {
    fn deduct_gold(ref self: Adventurer, value: u16) -> Adventurer {
        self.gold -= value;

        if (self.gold < 0) {
            self.gold = 0;
        }

        self
    }
    fn check_gold(self: Adventurer, value: u16) -> bool {
        self.gold >= value
    }

    fn get_item_at_slot(self: Adventurer, item: LootStatistics) -> LootStatistics {
        let item_slot = ItemUtils::get_slot(item.id);

        if (item_slot == constants::Slot::Weapon) {
            return self.weapon;
        } else if (item_slot == constants::Slot::Chest) {
            return self.chest;
        } else if (item_slot == constants::Slot::Head) {
            return self.head;
        } else if (item_slot == constants::Slot::Waist) {
            return self.waist;
        } else if (item_slot == constants::Slot::Foot) {
            return self.foot;
        } else if (item_slot == constants::Slot::Hand) {
            return self.hand;
        } else if (item_slot == constants::Slot::Neck) {
            return self.neck;
        } else {
            return self.ring;
        }
    }
    fn is_slot_free(self: Adventurer, item: LootStatistics) -> bool {
        let item_slot = ItemUtils::get_slot(item.id);

        if (item_slot == constants::Slot::Weapon) {
            return self.weapon.id == 0;
        } else if (item_slot == constants::Slot::Chest) {
            return self.chest.id == 0;
        } else if (item_slot == constants::Slot::Head) {
            return self.head.id == 0;
        } else if (item_slot == constants::Slot::Waist) {
            return self.waist.id == 0;
        } else if (item_slot == constants::Slot::Foot) {
            return self.foot.id == 0;
        } else if (item_slot == constants::Slot::Hand) {
            return self.hand.id == 0;
        } else if (item_slot == constants::Slot::Neck) {
            return self.neck.id == 0;
        } else if (item_slot == constants::Slot::Ring) {
            return self.ring.id == 0;
        } else {
            return false;
        }
    }
    fn get_beast(self: Adventurer) -> u8 {
        // TODO: return Beast struct generated from xp
        return 1;
    }

    fn get_level(self: Adventurer) -> u8 {
        return 1;
    }

    fn explore(ref self: Adventurer, adventurer_entropy: u64, game_entropy: u64) -> Adventurer {
        // get the exploration outcome
        let explore_outcome = ExploreUtils::get_random_explore(
            self, adventurer_entropy, game_entropy
        );

        // if the adventurer encounters a beast
        if (explore_outcome == discovery_constants::DiscoveryType::Beast) {
            // get starting health for the beast
            let beast_health = BeastUtils::get_starting_health(
                self, adventurer_entropy, game_entropy
            );
            // add the beast to the adventurer
            return self.add_beast(beast_health);
        // if the adventurer encounters an obstacle
        } else if (explore_outcome == discovery_constants::DiscoveryType::Obstacle) {
            // get a random obstacle
            let obstacle = ObstacleUtils::get_random_obstacle(
                self, adventurer_entropy, game_entropy
            );

            // get the xp reward for the obstacle
            let xp_reward = ObstacleUtils::get_xp_reward(obstacle);

            // grant adventurer and items xp gets xp for encountering an obstacle
            self.increase_adventurer_xp(xp_reward);
            self.increase_item_xp(xp_reward);

            // get damage from the obstacle, returning boolean for dodged and damage
            let (dodged, obstacle_damage) = ObstacleUtils::get_damage(self, obstacle);

            // if the adventurer did not dodge the obstacle
            if (dodged == false) {
                // deduct the damage from the adventurer health
                self.deduct_health(obstacle_damage);
                return self;
            // if the adventurer dodged the obstacle    
            } else {
                // simply return the adventurer
                return self;
            }
        } // if the adventurer encounters a discovery
        else if (explore_outcome == discovery_constants::DiscoveryType::LootStatistics) { // get the discovery type
            let item_type = ExploreUtils::get_discovery_type(
                self, adventurer_entropy, game_entropy
            );
            // if the discovery is gold
            if (item_type == discovery_constants::ItemDiscoveryType::Gold) { // get the gold amount
                let gold_disovery_amount = ExploreUtils::get_gold_discovery(
                    self, adventurer_entropy, game_entropy
                ); // add the gold to the adventurer
                return self.increase_gold(gold_disovery_amount); // if the discovery is xp
            } else if (item_type == discovery_constants::ItemDiscoveryType::XP) { // get the xp amount
                let xp_discovery_amount = ExploreUtils::get_xp_discovery(
                    self, adventurer_entropy, game_entropy
                ); // add the xp to the adventurer
                return self
                    .increase_adventurer_xp(xp_discovery_amount); // if the discovery is an item
            } else if (item_type == discovery_constants::ItemDiscoveryType::Health) { // get the health amount
                let health_discovery_amount = ExploreUtils::get_health_discovery(
                    self, adventurer_entropy, game_entropy
                ); // add the health to the adventurer
                return self.add_health(health_discovery_amount);
            }
        }
        return self;
    }

    // TODO: implement this function
    fn attack(ref self: Adventurer, adventurer_entropy: u64, game_entropy: u64) -> Adventurer {
        // get beast from adventurer
        // combat::calculate_damage_to_beast(adventurer, beast, adventurer_entropy, game_entropy);
        // if beast is dead, add xp to adventurer and items
        // if beast is not dead, calculate damage to adventurer and return adventurer
        //      the adventurer will have updated health for both adventurer and beast
        return self;
    }

    // TODO: implement this function
    fn flee(ref self: Adventurer, adventurer_entropy: u64, game_entropy: u64) -> Adventurer {
        // combat::attempt_flee(adventurer, adventurer_entropy, game_entropy;
        // if successful, return adventurer with adventurer.beast_health = 0;
        // if not successful, process beast counter_attack and return adventurer
        return self;
    }


    // TODO: implement this function
    fn luck(self: Adventurer) -> u8 {
        // calculate Luck from ring and neck greatness
        0
    }

    // in_battle returns true if the adventurer is in battle
    // @param self: Adventurer the adventurer to check if in battle
    // @return bool true if the adventurer is in battle, false otherwise
    fn in_battle(self: Adventurer) -> bool {
        if self.beast_health > 0 {
            true
        } else {
            false
        }
    }

    // deduct_beast_health deducts the beast health from the adventurer
    // if the beast health is less than 0, it sets the beast health to 0
    // @param self: Adventurer the adventurer to deduct the beast health from
    // @param value: u16 the amount to deduct from the beast health
    // @return Adventurer the adventurer with the beast health deducted
    fn deduct_beast_health(ref self: Adventurer, amount: u16) -> Adventurer {
        let mut new_beast_health = self.beast_health - amount;

        // check if killed
        if new_beast_health < 0 {
            self.beast_health = 0;
        } else {
            self.beast_health = new_beast_health;
        }
        self
    }
    fn add_beast(ref self: Adventurer, value: u16) -> Adventurer {
        self.beast_health = value;
        self
    }
    fn add_health(ref self: Adventurer, value: u16) -> Adventurer {
        // TODO: overflow check
        self.health = self.health + value;

        self
    }

    fn increase_gold(ref self: Adventurer, value: u16) -> Adventurer {
        // TODO: overflow check
        self.gold = self.gold + value;

        self
    }
    fn deduct_health(ref self: Adventurer, value: u16) -> Adventurer {
        // TODO: overflow check
        self.health = self.health - value;

        self
    }
    fn increase_adventurer_xp(ref self: Adventurer, value: u16) -> Adventurer {
        self.xp = self.xp + value;
        self
    }
    fn add_strength(ref self: Adventurer, value: u8) -> Adventurer {
        self.strength = self.strength + value;
        self
    }
    fn add_dexterity(ref self: Adventurer, value: u8) -> Adventurer {
        self.dexterity = self.dexterity + value;
        self
    }
    fn add_vitality(ref self: Adventurer, value: u8) -> Adventurer {
        self.vitality = self.vitality + value;
        self
    }
    fn add_intelligence(ref self: Adventurer, value: u8) -> Adventurer {
        self.intelligence = self.intelligence + value;
        self
    }
    fn add_wisdom(ref self: Adventurer, value: u8) -> Adventurer {
        self.wisdom = self.wisdom + value;
        self
    }
    fn add_charisma(ref self: Adventurer, value: u8) -> Adventurer {
        self.charisma = self.charisma + value;
        self
    }
    fn add_item(ref self: Adventurer, value: LootStatistics) -> Adventurer {
        let slot = ItemUtils::get_slot(value.id);

        if slot == 1 {
            self.add_weapon(value);
        }
        if slot == 2 {
            self.add_chest(value);
        }
        if slot == 3 {
            self.add_head(value);
        }
        if slot == 4 {
            self.add_waist(value);
        }
        if slot == 5 {
            self.add_foot(value);
        }
        if slot == 6 {
            self.add_hand(value);
        }
        if slot == 7 {
            self.add_neck(value);
        }
        if slot == 8 {
            self.add_ring(value);
        }
        self
    }
    fn add_weapon(ref self: Adventurer, value: LootStatistics) -> Adventurer {
        self.weapon = value;
        self
    }
    fn add_chest(ref self: Adventurer, value: LootStatistics) -> Adventurer {
        self.chest = value;
        self
    }
    fn add_head(ref self: Adventurer, value: LootStatistics) -> Adventurer {
        self.head = value;
        self
    }
    fn add_waist(ref self: Adventurer, value: LootStatistics) -> Adventurer {
        self.waist = value;
        self
    }
    fn add_foot(ref self: Adventurer, value: LootStatistics) -> Adventurer {
        self.foot = value;
        self
    }
    fn add_hand(ref self: Adventurer, value: LootStatistics) -> Adventurer {
        self.hand = value;
        self
    }
    fn add_neck(ref self: Adventurer, value: LootStatistics) -> Adventurer {
        self.neck = value;
        self
    }
    fn add_ring(ref self: Adventurer, value: LootStatistics) -> Adventurer {
        self.ring = value;
        self
    }

    // increase_item_xp is used to increase the xp of all items that are equipped
    // this is used when the adventurer kills a beast or takes damage from an obstacle
    // @param self: Adventurer - the adventurer calling the function
    // @param value: u16 - the amount of xp to increase the items by
    // @return Adventurer - the adventurer with the updated items
    fn increase_item_xp(ref self: Adventurer, value: u16) -> Adventurer {
        if self.weapon.id > 0 {
            self.weapon.xp = self.weapon.xp + value;
        }
        if self.chest.id > 0 {
            self.chest.xp = self.chest.xp + value;
        }
        if self.head.id > 0 {
            self.head.xp = self.head.xp + value;
        }
        if self.waist.id > 0 {
            self.waist.xp = self.waist.xp + value;
        }
        if self.foot.id > 0 {
            self.foot.xp = self.foot.xp + value;
        }
        if self.hand.id > 0 {
            self.hand.xp = self.hand.xp + value;
        }
        if self.neck.id > 0 {
            self.neck.xp = self.neck.xp + value;
        }
        if self.ring.id > 0 {
            self.ring.xp = self.ring.xp + value;
        }
        self
    }

    // create a new adventurer from a starting item and a block number
    // the block number is used to set the last action
    // the starting item is used to set the starting weapon
    // @param starting_item: the id of the starting item
    // @param block_number: the block number of the block that the adventurer was created in
    // @return Adventurer: the new adventurer
    fn new(starting_item: u8, block_number: u64) -> Adventurer {
        let last_action: u16 = (block_number % 512).try_into().unwrap();

        return Adventurer {
            last_action: last_action,
            health: 100,
            xp: 0,
            strength: 0,
            dexterity: 0,
            vitality: 0,
            intelligence: 0,
            wisdom: 0,
            charisma: 0,
            gold: 0,
            weapon: LootStatistics {
                id: starting_item, xp: 0, metadata: 1, 
                }, chest: LootStatistics {
                id: 0, xp: 0, metadata: 0, 
                }, head: LootStatistics {
                id: 0, xp: 0, metadata: 0, 
                }, waist: LootStatistics {
                id: 0, xp: 0, metadata: 0, 
                }, foot: LootStatistics {
                id: 0, xp: 0, metadata: 0, 
                }, hand: LootStatistics {
                id: 0, xp: 0, metadata: 0, 
                }, neck: LootStatistics {
                id: 0, xp: 0, metadata: 0, 
                }, ring: LootStatistics {
                id: 0, xp: 0, metadata: 0, 
            }, beast_health: 10, stat_upgrade_available: 0,
        };
    }

    // pack the adventurer into a single felt252
    // this is used to store the adventurer in the contract
    // @return the packed adventurer
    fn pack(self: Adventurer) -> felt252 {
        let mut packed = 0;
        packed = packed | pack_value(self.last_action.into(), pow::TWO_POW_242);
        packed = packed | pack_value(self.health.into(), pow::TWO_POW_233);
        packed = packed | pack_value(self.xp.into(), pow::TWO_POW_218);
        packed = packed | pack_value(self.strength.into(), pow::TWO_POW_213);
        packed = packed | pack_value(self.dexterity.into(), pow::TWO_POW_208);
        packed = packed | pack_value(self.vitality.into(), pow::TWO_POW_203);
        packed = packed | pack_value(self.intelligence.into(), pow::TWO_POW_198);
        packed = packed | pack_value(self.wisdom.into(), pow::TWO_POW_193);
        packed = packed | pack_value(self.charisma.into(), pow::TWO_POW_188);
        packed = packed | pack_value(self.gold.into(), pow::TWO_POW_179);

        packed = packed | pack_value(self.weapon.id.into(), pow::TWO_POW_172);
        packed = packed | pack_value(self.weapon.xp.into(), pow::TWO_POW_163);
        packed = packed | pack_value(self.weapon.metadata.into(), pow::TWO_POW_158);

        packed = packed | pack_value(self.chest.id.into(), pow::TWO_POW_151);
        packed = packed | pack_value(self.chest.xp.into(), pow::TWO_POW_142);
        packed = packed | pack_value(self.chest.metadata.into(), pow::TWO_POW_137);

        packed = packed | pack_value(self.head.id.into(), pow::TWO_POW_130);
        packed = packed | pack_value(self.head.xp.into(), pow::TWO_POW_121);
        packed = packed | pack_value(self.head.metadata.into(), pow::TWO_POW_116);

        packed = packed | pack_value(self.waist.id.into(), pow::TWO_POW_109);
        packed = packed | pack_value(self.waist.xp.into(), pow::TWO_POW_100);
        packed = packed | pack_value(self.waist.metadata.into(), pow::TWO_POW_95);

        packed = packed | pack_value(self.foot.id.into(), pow::TWO_POW_88);
        packed = packed | pack_value(self.foot.xp.into(), pow::TWO_POW_79);
        packed = packed | pack_value(self.foot.metadata.into(), pow::TWO_POW_74);

        packed = packed | pack_value(self.hand.id.into(), pow::TWO_POW_67);
        packed = packed | pack_value(self.hand.xp.into(), pow::TWO_POW_58);
        packed = packed | pack_value(self.hand.metadata.into(), pow::TWO_POW_53);

        packed = packed | pack_value(self.neck.id.into(), pow::TWO_POW_46);
        packed = packed | pack_value(self.neck.xp.into(), pow::TWO_POW_37);
        packed = packed | pack_value(self.neck.metadata.into(), pow::TWO_POW_32);

        packed = packed | pack_value(self.ring.id.into(), pow::TWO_POW_25);
        packed = packed | pack_value(self.ring.xp.into(), pow::TWO_POW_16);
        packed = packed | pack_value(self.ring.metadata.into(), pow::TWO_POW_11);

        packed = packed | pack_value(self.beast_health.into(), pow::TWO_POW_1);
        packed = packed | pack_value(self.stat_upgrade_available.into(), 1);

        packed.try_into().unwrap()
    }

    // unpack a felt252 into an Adventurer
    // @param packed: felt252
    // @return Adventurer
    fn unpack(packed: felt252) -> Adventurer {
        let packed = packed.into();

        Adventurer {
            last_action: U256TryIntoU16::try_into(
                unpack_value(packed, pow::TWO_POW_242, mask::MASK_9)
            )
                .unwrap(),
            health: U256TryIntoU16::try_into(unpack_value(packed, pow::TWO_POW_233, mask::MASK_10))
                .unwrap(),
            xp: U256TryIntoU16::try_into(unpack_value(packed, pow::TWO_POW_218, mask::MASK_15))
                .unwrap(),
            strength: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_213, mask::MASK_5))
                .unwrap(),
            dexterity: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_208, mask::MASK_5))
                .unwrap(),
            vitality: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_203, mask::MASK_5))
                .unwrap(),
            intelligence: U256TryIntoU8::try_into(
                unpack_value(packed, pow::TWO_POW_198, mask::MASK_5)
            )
                .unwrap(),
            wisdom: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_193, mask::MASK_5))
                .unwrap(),
            charisma: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_188, mask::MASK_5))
                .unwrap(),
            gold: U256TryIntoU16::try_into(unpack_value(packed, pow::TWO_POW_179, mask::MASK_9))
                .unwrap(),
            weapon: LootStatistics {
                id: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_172, mask::MASK_7))
                    .unwrap(),
                xp: U256TryIntoU16::try_into(unpack_value(packed, pow::TWO_POW_163, mask::MASK_9))
                    .unwrap(),
                metadata: U256TryIntoU8::try_into(
                    unpack_value(packed, pow::TWO_POW_158, mask::MASK_5)
                )
                    .unwrap(),
                }, chest: LootStatistics {
                id: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_151, mask::MASK_7))
                    .unwrap(),
                xp: U256TryIntoU16::try_into(unpack_value(packed, pow::TWO_POW_142, mask::MASK_9))
                    .unwrap(),
                metadata: U256TryIntoU8::try_into(
                    unpack_value(packed, pow::TWO_POW_137, mask::MASK_5)
                )
                    .unwrap(),
                }, head: LootStatistics {
                id: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_130, mask::MASK_7))
                    .unwrap(),
                xp: U256TryIntoU16::try_into(unpack_value(packed, pow::TWO_POW_121, mask::MASK_9))
                    .unwrap(),
                metadata: U256TryIntoU8::try_into(
                    unpack_value(packed, pow::TWO_POW_116, mask::MASK_5)
                )
                    .unwrap(),
                }, waist: LootStatistics {
                id: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_109, mask::MASK_7))
                    .unwrap(),
                xp: U256TryIntoU16::try_into(unpack_value(packed, pow::TWO_POW_100, mask::MASK_9))
                    .unwrap(),
                metadata: U256TryIntoU8::try_into(
                    unpack_value(packed, pow::TWO_POW_95, mask::MASK_5)
                )
                    .unwrap(),
                }, foot: LootStatistics {
                id: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_88, mask::MASK_7))
                    .unwrap(),
                xp: U256TryIntoU16::try_into(unpack_value(packed, pow::TWO_POW_79, mask::MASK_9))
                    .unwrap(),
                metadata: U256TryIntoU8::try_into(
                    unpack_value(packed, pow::TWO_POW_74, mask::MASK_5)
                )
                    .unwrap(),
                }, hand: LootStatistics {
                id: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_67, mask::MASK_7))
                    .unwrap(),
                xp: U256TryIntoU16::try_into(unpack_value(packed, pow::TWO_POW_58, mask::MASK_9))
                    .unwrap(),
                metadata: U256TryIntoU8::try_into(
                    unpack_value(packed, pow::TWO_POW_53, mask::MASK_5)
                )
                    .unwrap(),
                }, neck: LootStatistics {
                id: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_46, mask::MASK_7))
                    .unwrap(),
                xp: U256TryIntoU16::try_into(unpack_value(packed, pow::TWO_POW_37, mask::MASK_9))
                    .unwrap(),
                metadata: U256TryIntoU8::try_into(
                    unpack_value(packed, pow::TWO_POW_32, mask::MASK_5)
                )
                    .unwrap(),
                }, ring: LootStatistics {
                id: U256TryIntoU8::try_into(unpack_value(packed, pow::TWO_POW_25, mask::MASK_7))
                    .unwrap(),
                xp: U256TryIntoU16::try_into(unpack_value(packed, pow::TWO_POW_16, mask::MASK_9))
                    .unwrap(),
                metadata: U256TryIntoU8::try_into(
                    unpack_value(packed, pow::TWO_POW_11, mask::MASK_5)
                )
                    .unwrap(),
            },
            beast_health: U256TryIntoU16::try_into(
                unpack_value(packed, pow::TWO_POW_1, mask::MASK_10)
            )
                .unwrap(),
            stat_upgrade_available: U256TryIntoU8::try_into(unpack_value(packed, 1, MASK_BOOL))
                .unwrap(),
        }
    }
}
#[test]
#[available_gas(5000000)]
fn test_adventurer() {
    let adventurer = Adventurer {
        last_action: 511,
        health: 1023,
        xp: 32767,
        strength: 31,
        dexterity: 31,
        vitality: 31,
        intelligence: 31,
        wisdom: 31,
        charisma: 31,
        gold: 511,
        weapon: LootStatistics {
            id: 100, xp: 511, metadata: 1, 
            }, chest: LootStatistics {
            id: 99, xp: 511, metadata: 2, 
            }, head: LootStatistics {
            id: 98, xp: 511, metadata: 3, 
            }, waist: LootStatistics {
            id: 87, xp: 511, metadata: 4, 
            }, foot: LootStatistics {
            id: 78, xp: 511, metadata: 5, 
            }, hand: LootStatistics {
            id: 34, xp: 511, metadata: 6, 
            }, neck: LootStatistics {
            id: 32, xp: 511, metadata: 7, 
            }, ring: LootStatistics {
            id: 1, xp: 511, metadata: 8, 
        }, beast_health: 1023, stat_upgrade_available: 1,
    };
    let packed = adventurer.pack();
    let unpacked = AdventurerActions::unpack(packed);
    assert(adventurer.last_action == unpacked.last_action, 'last_action');
    assert(adventurer.health == unpacked.health, 'health');
    assert(adventurer.xp == unpacked.xp, 'xp');
    assert(adventurer.strength == unpacked.strength, 'strength');
    assert(adventurer.dexterity == unpacked.dexterity, 'dexterity');
    assert(adventurer.vitality == unpacked.vitality, 'vitality');
    assert(adventurer.intelligence == unpacked.intelligence, 'intelligence');
    assert(adventurer.wisdom == unpacked.wisdom, 'wisdom');
    assert(adventurer.charisma == unpacked.charisma, 'charisma');
    assert(adventurer.gold == unpacked.gold, 'luck');
    assert(adventurer.weapon.id == unpacked.weapon.id, 'weapon.id');
    assert(adventurer.weapon.xp == unpacked.weapon.xp, 'weapon.xp');
    assert(adventurer.weapon.metadata == unpacked.weapon.metadata, 'weapon.metadata');
    assert(adventurer.chest.id == unpacked.chest.id, 'chest.id');
    assert(adventurer.chest.xp == unpacked.chest.xp, 'chest.xp');
    assert(adventurer.chest.metadata == unpacked.chest.metadata, 'chest.metadata');
    assert(adventurer.head.id == unpacked.head.id, 'head.id');
    assert(adventurer.head.xp == unpacked.head.xp, 'head.xp');
    assert(adventurer.head.metadata == unpacked.head.metadata, 'head.metadata');
    assert(adventurer.waist.id == unpacked.waist.id, 'waist.id');
    assert(adventurer.waist.xp == unpacked.waist.xp, 'waist.xp');
    assert(adventurer.waist.metadata == unpacked.waist.metadata, 'waist.metadata');
    assert(adventurer.foot.id == unpacked.foot.id, 'foot.id');
    assert(adventurer.foot.xp == unpacked.foot.xp, 'foot.xp');
    assert(adventurer.foot.metadata == unpacked.foot.metadata, 'foot.metadata');
    assert(adventurer.hand.id == unpacked.hand.id, 'hand.id');
    assert(adventurer.hand.xp == unpacked.hand.xp, 'hand.xp');
    assert(adventurer.hand.metadata == unpacked.hand.metadata, 'hand.metadata');
    assert(adventurer.neck.id == unpacked.neck.id, 'neck.id');
    assert(adventurer.neck.xp == unpacked.neck.xp, 'neck.xp');
    assert(adventurer.neck.metadata == unpacked.neck.metadata, 'neck.metadata');
    assert(adventurer.ring.id == unpacked.ring.id, 'ring.id');
    assert(adventurer.ring.xp == unpacked.ring.xp, 'ring.xp');
    assert(adventurer.ring.metadata == unpacked.ring.metadata, 'ring.metadata');
    assert(adventurer.beast_health == unpacked.beast_health, 'beast_health');
    assert(
        adventurer.stat_upgrade_available == unpacked.stat_upgrade_available,
        'stat_upgrade_available'
    );
}

#[test]
#[available_gas(5000000)]
fn test_new_adventurer() {
    let new_adventurer = AdventurerActions::new(1, 1);

    new_adventurer.pack();

    assert(new_adventurer.health == 100, 'health');
}

#[test]
#[available_gas(5000000)]
fn test_health() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let mut adventurer = AdventurerActions::new(1, 1);

    adventurer.add_health(5);

    assert(adventurer.health == 105, 'health');
}

#[test]
#[available_gas(5000000)]
fn test_deduct_health() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let mut adventurer = AdventurerActions::new(1, 1);

    adventurer.deduct_health(5);

    assert(adventurer.health == 95, 'strength');
}

#[test]
#[available_gas(5000000)]
fn test_xp() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let mut adventurer = AdventurerActions::new(1, 1);

    adventurer.increase_adventurer_xp(5);

    assert(adventurer.xp == 5, 'xp');
}

#[test]
#[available_gas(5000000)]
fn test_strength() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let mut adventurer = AdventurerActions::new(1, 1);

    adventurer.add_strength(1);

    assert(adventurer.strength == 1, 'strength');
}

#[test]
#[available_gas(5000000)]
fn test_add_weapon() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let mut adventurer = AdventurerActions::new(1, 1);

    let item = LootStatistics { id: 1, xp: 1, metadata: 0 };

    adventurer.add_weapon(item);

    assert(adventurer.weapon.id == 1, 'weapon.id');
    assert(adventurer.weapon.xp == 1, 'weapon.xp');
    assert(adventurer.weapon.metadata == 0, 'weapon.metadata');
}


#[test]
#[available_gas(5000000)]
fn test_increase_item_xp() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let mut adventurer = AdventurerActions::new(1, 1);

    let item_pendant = LootStatistics { id: 1, xp: 1, metadata: 0 };
    let item_silver_ring = LootStatistics { id: 4, xp: 1, metadata: 0 };
    let item_ghost_wand = LootStatistics { id: 9, xp: 1, metadata: 0 };
    let item_silk_robe = LootStatistics { id: 18, xp: 1, metadata: 0 };

    adventurer.add_item(item_pendant);
    adventurer.add_item(item_silver_ring);
    adventurer.add_item(item_ghost_wand);
    adventurer.add_item(item_silk_robe);

    adventurer.increase_item_xp(1);

    assert(adventurer.neck.xp == 2, 'weapon.xp');
    assert(adventurer.ring.xp == 2, 'weapon.xp');
    assert(adventurer.weapon.xp == 2, 'weapon.xp');
    assert(adventurer.chest.xp == 2, 'weapon.xp');
}

#[test]
#[available_gas(5000000)]
fn test_deduct_beast_health() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let mut adventurer = AdventurerActions::new(1, 1);

    adventurer.add_beast(100);
    assert(adventurer.beast_health == 100, 'beast_health');

    adventurer.deduct_beast_health(5);
    assert(adventurer.beast_health == 95, 'beast_health');
}

#[test]
#[available_gas(5000000)]
fn test_explore_beast_discovery() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let adventurer_entropy = 0;
    let game_entropy = 0;

    // zero out beast health on adventurer
    adventurer.beast_health = 0;

    // exploring with zero entropy will result in a beast discovery
    adventurer.explore(adventurer_entropy, game_entropy);
    assert(adventurer.beast_health != 0, 'adventurer should find beast');
}

#[test]
#[available_gas(5000000)]
fn test_explore_obstacle_discovery() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let adventurer_entropy = 0;
    let game_entropy = 1;

    // exploring with 1 entropy will result in an obstacle discovery which will currently do 1 damage
    adventurer.explore(adventurer_entropy, game_entropy);
    assert(adventurer.health < 99, 'advntr should take obstacle dmg');
}

#[test]
#[available_gas(5000000)]
fn test_explore_gold_discovery() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let adventurer_entropy = 0;
    let game_entropy = 2;
    adventurer.xp = 1;

    // exploring with entropy 2 and no adventurer xp will result in adventurer discoverying gold (currently hard coded to 1)
    adventurer.explore(adventurer_entropy, game_entropy);

    assert(adventurer.gold > 0, 'advntr should discover gold');
}

#[test]
#[available_gas(5000000)]
fn test_explore_health_discovery() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let adventurer_entropy = 0;
    let game_entropy = 2;
    adventurer.xp = 2;

    // exploring with entropy 2 and no adventurer xp will result in an obstacle discovery which will currently do 1 damage
    adventurer.explore(adventurer_entropy, game_entropy);
    assert(adventurer.health > 100, 'advntr should discover health');
}

#[test]
#[available_gas(5000000)]
fn test_explore_xp_discovery() {
    let mut adventurer = AdventurerActions::new(1, 1);
    let adventurer_entropy = 0;
    let game_entropy = 2;
    adventurer.xp = 3;

    // exploring with entropy 2 and no adventurer xp will result in an obstacle discovery which will currently do 1 damage
    adventurer.explore(adventurer_entropy, game_entropy);
    assert(adventurer.xp > 0, 'advntr should discover xp');
}