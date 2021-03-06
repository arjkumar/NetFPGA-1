#!/usr/local/bin/perl -w
# make_pkts.pl
#

use SimLib;
use TaggingLib;

$delay = '@4us';
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

my $length = 100;
my $DA_sub = ':dd:dd:dd:dd:dd';
my $SA_sub = ':55:55:55:55:55';
my $DA;
my $SA;
my $pkt;
my $vlan_pkt;
my $in_port;
my $out_port;
my $exp_port;
my $i = 0;
my $j = 0;
my $temp;
my $type;

$delay = '@6us';
# set up the output port so that you send each packet out the next port
for($i=0; $i<8; $i++) {
  nf_PCI_write32($delay, 0, HARDWIRE_LOOKUP_OUTPUT_PORTS_BASE_REG()+$i*4, 1<<(($i+2)%8));
}

# Initialize and setup VLAN tag values for testing
my @vlan_tag = ();
for($i=0; $i<4; $i++) {
  $vlan_tag[$i] = int(rand(4093)) + 1;
}

# Setup VID value for each input port
nf_PCI_write32($delay, 0, VLAN_REMOVER_INPORT_0_VLAN_TAG_REG(), $vlan_tag[0]);
nf_PCI_write32($delay, 0, VLAN_REMOVER_INPORT_1_VLAN_TAG_REG(), $vlan_tag[1]);
nf_PCI_write32($delay, 0, VLAN_REMOVER_INPORT_2_VLAN_TAG_REG(), $vlan_tag[2]);
nf_PCI_write32($delay, 0, VLAN_REMOVER_INPORT_3_VLAN_TAG_REG(), $vlan_tag[3]);
# verify the values above
nf_PCI_read32($delay, 0, VLAN_REMOVER_INPORT_0_VLAN_TAG_REG(), $vlan_tag[0]);
nf_PCI_read32($delay, 0, VLAN_REMOVER_INPORT_1_VLAN_TAG_REG(), $vlan_tag[1]);
nf_PCI_read32($delay, 0, VLAN_REMOVER_INPORT_2_VLAN_TAG_REG(), $vlan_tag[2]);
nf_PCI_read32($delay, 0, VLAN_REMOVER_INPORT_3_VLAN_TAG_REG(), $vlan_tag[3]);

# Set the values as 'passthrough'
my $vlan_through = 0;
nf_PCI_write32($delay, 0, VLAN_ADDER_0_VLAN_TAG_REG(), $vlan_through);
nf_PCI_write32($delay, 0, VLAN_ADDER_1_VLAN_TAG_REG(), $vlan_through);
nf_PCI_write32($delay, 0, VLAN_ADDER_2_VLAN_TAG_REG(), $vlan_through);
nf_PCI_write32($delay, 0, VLAN_ADDER_3_VLAN_TAG_REG(), $vlan_through);
# verify the values above
nf_PCI_read32($delay, 0, VLAN_ADDER_0_VLAN_TAG_REG(), $vlan_through);
nf_PCI_read32($delay, 0, VLAN_ADDER_1_VLAN_TAG_REG(), $vlan_through);
nf_PCI_read32($delay, 0, VLAN_ADDER_2_VLAN_TAG_REG(), $vlan_through);
nf_PCI_read32($delay, 0, VLAN_ADDER_3_VLAN_TAG_REG(), $vlan_through);

# Specify output port
# (Random value. The packets should not come to the port anyway.)
my $outport_val = int(rand(4));
nf_PCI_write32($delay, 0, OUT_AGGR_OUTPORT_REG(), $outport_val);
nf_PCI_read32($delay, 0, OUT_AGGR_OUTPORT_REG(), $outport_val);

# Set the packet length as small/large/random size.
# send and receive pkts to each port
$delay = '@17us';
for($j=0; $j<15; $j++){
  if ($j < 5){
    $length = 60;
  } elsif($j < 10){
    $length = 1500;
  } else {
    $length = 60 + int(rand(1440));
  }
  # send and receive 3 pkts into each port
  $delay = '@34us';
  for($i=0; $i<12; $i++){
    $temp = sprintf("%02x", $i);
    $DA = $temp . $DA_sub;
    $SA = $temp . $SA_sub;
    $in_port = ($i%4) + 1;
    $exp_port = ($in_port%4)+1;
    $type = 0x0800;

    my $wrong_vlan_tag = int(rand(4093))+1;
    for (my $k=0; $k<4; $k++){
      if ($wrong_vlan_tag == $vlan_tag[$k]){
        $wrong_vlan_tag = 0;
        last;
      }
    }
    $pkt = make_vlan_pkt($length, $DA, $SA, $wrong_vlan_tag);

    nf_packet_in($in_port, $length+4, $delay, $batch, $pkt);
    # We don't expect any packets on output ports
  }
}

$delay = '@340us';

# Check if no packets have reached output queues
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_0_NUM_PKTS_RECEIVED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_0_NUM_PKTS_DROPPED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_1_NUM_PKTS_RECEIVED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_1_NUM_PKTS_DROPPED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_2_NUM_PKTS_RECEIVED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_2_NUM_PKTS_DROPPED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_3_NUM_PKTS_RECEIVED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_3_NUM_PKTS_DROPPED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_4_NUM_PKTS_RECEIVED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_4_NUM_PKTS_DROPPED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_5_NUM_PKTS_RECEIVED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_5_NUM_PKTS_DROPPED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_6_NUM_PKTS_RECEIVED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_6_NUM_PKTS_DROPPED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_7_NUM_PKTS_RECEIVED_REG(), 0);
nf_PCI_read32($delay, 0, BRAM_OQ_QUEUE_7_NUM_PKTS_DROPPED_REG(), 0);

# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
