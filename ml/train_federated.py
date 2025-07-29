#!/usr/bin/env python3
"""
Federated learning training for MobileNLD-FL
Implements FedAvg autoencoder baseline and personalized federated autoencoder (PFL-AE)
"""

import argparse
import numpy as np
import pandas as pd
import tensorflow as tf
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import flwr as fl
from flwr.common import NDArrays, Scalar
import logging
from sklearn.metrics import roc_auc_score, roc_curve
import matplotlib.pyplot as plt
import seaborn as sns

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AutoEncoder(tf.keras.Model):
    """
    Autoencoder for anomaly detection
    Architecture: [10] -> [32, 16] -> [16, 32] -> [10]
    """
    
    def __init__(self, input_dim=10, encoding_dims=[32, 16]):
        super(AutoEncoder, self).__init__()
        self.input_dim = input_dim
        self.encoding_dims = encoding_dims
        
        # Encoder
        self.encoder = tf.keras.Sequential([
            tf.keras.layers.Dense(encoding_dims[0], activation='relu', input_shape=(input_dim,)),
            tf.keras.layers.Dense(encoding_dims[1], activation='relu'),
        ])
        
        # Decoder
        self.decoder = tf.keras.Sequential([
            tf.keras.layers.Dense(encoding_dims[0], activation='relu', input_shape=(encoding_dims[1],)),
            tf.keras.layers.Dense(input_dim, activation='linear'),
        ])
    
    def call(self, x):
        encoded = self.encoder(x)
        decoded = self.decoder(encoded)
        return decoded
    
    def encode(self, x):
        return self.encoder(x)

class PersonalizedAutoEncoder(tf.keras.Model):
    """
    Personalized Federated Autoencoder (PFL-AE)
    Shared encoder + local decoder architecture
    """
    
    def __init__(self, input_dim=10, encoding_dims=[32, 16], shared_encoder=True):
        super(PersonalizedAutoEncoder, self).__init__()
        self.input_dim = input_dim
        self.encoding_dims = encoding_dims
        self.shared_encoder = shared_encoder
        
        # Shared encoder (federated)
        self.encoder = tf.keras.Sequential([
            tf.keras.layers.Dense(encoding_dims[0], activation='relu', input_shape=(input_dim,)),
            tf.keras.layers.Dense(encoding_dims[1], activation='relu'),
        ])
        
        # Local decoder (personalized)
        self.decoder = tf.keras.Sequential([
            tf.keras.layers.Dense(encoding_dims[0], activation='relu', input_shape=(encoding_dims[1],)),
            tf.keras.layers.Dense(input_dim, activation='linear'),
        ])
    
    def call(self, x):
        encoded = self.encoder(x)
        decoded = self.decoder(encoded)
        return decoded
    
    def encode(self, x):
        return self.encoder(x)
    
    def get_shared_weights(self):
        """Get encoder weights for federated aggregation"""
        return self.encoder.get_weights()
    
    def set_shared_weights(self, weights):
        """Set encoder weights from federated aggregation"""
        self.encoder.set_weights(weights)

class FederatedClient(fl.client.NumPyClient):
    """
    Flower federated learning client for MobileNLD-FL
    """
    
    def __init__(self, client_id: str, model_type: str = "fedavg"):
        self.client_id = client_id
        self.model_type = model_type
        self.model = None
        self.X_train = None
        self.X_test = None
        self.y_train = None
        self.y_test = None
        self.training_history = []
        
    def load_data(self, data_dir: str = "ml/federated_data"):
        """Load client-specific data"""
        data_path = Path(data_dir)
        
        try:
            # Load features and labels
            self.X_train = np.load(data_path / f"{self.client_id}_features.npy")
            self.y_train = np.load(data_path / f"{self.client_id}_labels.npy")
            
            # Split into train/test (80/20)
            n_samples = len(self.X_train)
            n_train = int(0.8 * n_samples)
            
            indices = np.random.permutation(n_samples)
            train_indices = indices[:n_train]
            test_indices = indices[n_train:]
            
            self.X_test = self.X_train[test_indices]
            self.y_test = self.y_train[test_indices]
            self.X_train = self.X_train[train_indices]
            self.y_train = self.y_train[train_indices]
            
            logger.info(f"{self.client_id}: Loaded {len(self.X_train)} train, {len(self.X_test)} test samples")
            logger.info(f"{self.client_id}: Anomaly rate - train: {self.y_train.mean():.2%}, test: {self.y_test.mean():.2%}")
            
        except FileNotFoundError as e:
            logger.error(f"Data not found for {self.client_id}: {e}")
            raise
    
    def create_model(self):
        """Create model based on algorithm type"""
        if self.model_type == "fedavg":
            self.model = AutoEncoder(input_dim=10, encoding_dims=[32, 16])
        elif self.model_type == "pflae":
            self.model = PersonalizedAutoEncoder(input_dim=10, encoding_dims=[32, 16])
        else:
            raise ValueError(f"Unknown model type: {self.model_type}")
        
        # Compile model
        self.model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
            loss='mse',
            metrics=['mae']
        )
        
        # Initialize with dummy forward pass
        dummy_input = tf.random.normal((1, 10))
        _ = self.model(dummy_input)
        
        logger.info(f"{self.client_id}: Created {self.model_type} model")
    
    def get_parameters(self, config: Dict[str, Scalar]) -> NDArrays:
        """Get model parameters for federated aggregation"""
        if self.model_type == "pflae":
            # Only share encoder weights for PFL-AE
            return self.model.get_shared_weights()
        else:
            # Share all weights for FedAvg
            return self.model.get_weights()
    
    def set_parameters(self, parameters: NDArrays) -> None:
        """Set model parameters from federated aggregation"""
        if self.model_type == "pflae":
            # Only update encoder weights for PFL-AE
            self.model.set_shared_weights(parameters)
        else:
            # Update all weights for FedAvg
            self.model.set_weights(parameters)
    
    def fit(self, parameters: NDArrays, config: Dict[str, Scalar]) -> Tuple[NDArrays, int, Dict[str, Scalar]]:
        """Train model on local data"""
        # Set parameters from server
        self.set_parameters(parameters)
        
        # Training configuration
        epochs = int(config.get("epochs", 1))
        batch_size = int(config.get("batch_size", 32))
        
        # Train model (unsupervised - only use X for reconstruction)
        history = self.model.fit(
            self.X_train, self.X_train,  # Autoencoder: input = target
            epochs=epochs,
            batch_size=batch_size,
            validation_data=(self.X_test, self.X_test),
            verbose=0
        )
        
        # Store training history
        self.training_history.extend(history.history['loss'])
        
        # Calculate communication cost
        params = self.get_parameters({})
        comm_cost = sum(p.nbytes for p in params)
        
        logger.info(f"{self.client_id}: Trained for {epochs} epochs, loss: {history.history['loss'][-1]:.4f}")
        
        return self.get_parameters({}), len(self.X_train), {
            "loss": history.history['loss'][-1],
            "val_loss": history.history['val_loss'][-1],
            "comm_cost_bytes": comm_cost
        }
    
    def evaluate(self, parameters: NDArrays, config: Dict[str, Scalar]) -> Tuple[float, int, Dict[str, Scalar]]:
        """Evaluate model on local data"""
        # Set parameters from server
        self.set_parameters(parameters)
        
        # Reconstruction error for anomaly detection
        X_pred = self.model.predict(self.X_test, verbose=0)
        reconstruction_errors = np.mean(np.square(self.X_test - X_pred), axis=1)
        
        # Calculate AUC for anomaly detection
        if len(np.unique(self.y_test)) > 1:  # Need both normal and anomaly samples
            auc = roc_auc_score(self.y_test, reconstruction_errors)
        else:
            auc = 0.5  # Random performance if only one class
        
        # Average reconstruction loss
        avg_loss = np.mean(reconstruction_errors)
        
        logger.info(f"{self.client_id}: Evaluation - Loss: {avg_loss:.4f}, AUC: {auc:.4f}")
        
        return avg_loss, len(self.X_test), {
            "auc": auc,
            "reconstruction_error": avg_loss
        }

class FederatedTrainer:
    """
    Main federated learning trainer for MobileNLD-FL
    """
    
    def __init__(self, algorithm: str = "fedavg", n_clients: int = 5):
        self.algorithm = algorithm
        self.n_clients = n_clients
        self.clients = {}
        self.results = {
            'rounds': [],
            'train_losses': [],
            'val_losses': [],
            'aucs': [],
            'comm_costs': []
        }
    
    def setup_clients(self, data_dir: str = "ml/federated_data"):
        """Setup federated clients"""
        logger.info(f"Setting up {self.n_clients} clients for {self.algorithm}")
        
        for i in range(self.n_clients):
            client_id = f"client_{i}"
            client = FederatedClient(client_id, self.algorithm)
            
            try:
                client.load_data(data_dir)
                client.create_model()
                self.clients[client_id] = client
            except Exception as e:
                logger.error(f"Failed to setup {client_id}: {e}")
                continue
        
        logger.info(f"Successfully setup {len(self.clients)} clients")
    
    def create_client_fn(self):
        """Create client function for Flower simulation"""
        def client_fn(cid: str) -> fl.client.Client:
            return self.clients[cid]
        return client_fn
    
    def run_simulation(self, num_rounds: int = 20):
        """Run federated learning simulation"""
        logger.info(f"Starting {self.algorithm} simulation for {num_rounds} rounds")
        
        # Configure strategy
        if self.algorithm == "fedavg":
            strategy = fl.server.strategy.FedAvg(
                fraction_fit=1.0,  # Use all clients
                fraction_evaluate=1.0,
                min_fit_clients=len(self.clients),
                min_evaluate_clients=len(self.clients),
                min_available_clients=len(self.clients),
            )
        elif self.algorithm == "pflae":
            # Use FedAvg strategy but only aggregate encoder weights
            strategy = fl.server.strategy.FedAvg(
                fraction_fit=1.0,
                fraction_evaluate=1.0,
                min_fit_clients=len(self.clients),
                min_evaluate_clients=len(self.clients),
                min_available_clients=len(self.clients),
            )
        else:
            raise ValueError(f"Unknown algorithm: {self.algorithm}")
        
        # Configure client resources
        client_resources = {"num_cpus": 1, "num_gpus": 0}
        
        # Run simulation
        history = fl.simulation.start_simulation(
            client_fn=self.create_client_fn(),
            num_clients=len(self.clients),
            config=fl.server.ServerConfig(num_rounds=num_rounds),
            strategy=strategy,
            client_resources=client_resources,
            ray_init_args={"include_dashboard": False}
        )
        
        logger.info("Simulation completed")
        return history
    
    def evaluate_final_performance(self):
        """Evaluate final performance across all clients"""
        logger.info("Evaluating final performance...")
        
        all_aucs = []
        all_losses = []
        total_comm_cost = 0
        
        for client_id, client in self.clients.items():
            # Get final model parameters (simulate final round)
            params = client.get_parameters({})
            
            # Evaluate
            loss, n_samples, metrics = client.evaluate(params, {})
            
            all_aucs.append(metrics['auc'])
            all_losses.append(loss)
            
            # Calculate total communication cost
            comm_cost = sum(p.nbytes for p in params)
            total_comm_cost += comm_cost * 20  # 20 rounds
            
            logger.info(f"{client_id}: Final AUC = {metrics['auc']:.4f}, Loss = {loss:.4f}")
        
        # Summary statistics
        avg_auc = np.mean(all_aucs)
        std_auc = np.std(all_aucs)
        avg_loss = np.mean(all_losses)
        
        results_summary = {
            'algorithm': self.algorithm,
            'avg_auc': avg_auc,
            'std_auc': std_auc,
            'avg_loss': avg_loss,
            'total_comm_cost_mb': total_comm_cost / (1024 * 1024),
            'client_aucs': all_aucs
        }
        
        logger.info(f"Final Results - Algorithm: {self.algorithm}")
        logger.info(f"Average AUC: {avg_auc:.4f} ± {std_auc:.4f}")
        logger.info(f"Average Loss: {avg_loss:.4f}")
        logger.info(f"Total Communication Cost: {total_comm_cost / (1024 * 1024):.2f} MB")
        
        return results_summary
    
    def save_results(self, results: Dict, output_dir: str = "ml/results"):
        """Save training results"""
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Save results as CSV
        results_df = pd.DataFrame([results])
        results_file = output_path / f"{self.algorithm}_results.csv"
        results_df.to_csv(results_file, index=False)
        
        logger.info(f"Results saved to: {results_file}")
        return results_file

def main():
    """Main training function"""
    parser = argparse.ArgumentParser(description="MobileNLD-FL Federated Training")
    parser.add_argument("--algo", choices=["fedavg", "pflae"], default="fedavg",
                      help="Federated learning algorithm")
    parser.add_argument("--rounds", type=int, default=20,
                      help="Number of federated rounds")
    parser.add_argument("--clients", type=int, default=5,
                      help="Number of federated clients")
    
    args = parser.parse_args()
    
    print(f"=== MobileNLD-FL Federated Training ===")
    print(f"Algorithm: {args.algo}")
    print(f"Rounds: {args.rounds}")
    print(f"Clients: {args.clients}")
    
    try:
        # Initialize trainer
        trainer = FederatedTrainer(algorithm=args.algo, n_clients=args.clients)
        
        # Setup clients
        trainer.setup_clients()
        
        if len(trainer.clients) == 0:
            print("❌ No clients setup successfully. Run feature extraction first:")
            print("   python ml/feature_extract.py")
            return
        
        # Run federated training
        history = trainer.run_simulation(num_rounds=args.rounds)
        
        # Evaluate final performance
        results = trainer.evaluate_final_performance()
        
        # Save results
        results_file = trainer.save_results(results)
        
        print(f"\n✅ Training completed!")
        print(f"📊 Algorithm: {args.algo}")
        print(f"📈 Average AUC: {results['avg_auc']:.4f} ± {results['std_auc']:.4f}")
        print(f"💾 Results saved to: {results_file}")
        
    except Exception as e:
        print(f"❌ Training failed: {e}")
        logger.exception("Training error")

if __name__ == "__main__":
    main()